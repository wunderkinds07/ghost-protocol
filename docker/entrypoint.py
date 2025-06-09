#!/usr/bin/env python3
"""
Docker container entrypoint for 1stDibs data extraction
Processes a chunk of URLs based on environment variables
"""

import os
import json
import time
import gzip
import hashlib
from pathlib import Path
from datetime import datetime
import logging
import sys

# Add src to path
sys.path.append('/app')

from src.parsers.html_collector import RawHTMLCollector
from src.extractors.product_extractor import ProductExtractor
from notifier import notify_start, notify_progress, notify_milestone, notify_complete, notify_error, notify_warning
from s3_uploader import get_s3_uploader

# Ensure logs directory exists
Path('/app/data/logs').mkdir(parents=True, exist_ok=True)

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/app/data/logs/extraction.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class ContainerProcessor:
    def __init__(self):
        self.container_id = os.environ.get('CONTAINER_ID', '1')
        self.chunk_start = int(os.environ.get('URL_CHUNK_START', '0'))
        self.chunk_size = int(os.environ.get('URL_CHUNK_SIZE', '5000'))
        
        # Setup directories
        self.base_dir = Path('/app/data')
        self.raw_html_dir = self.base_dir / 'raw_html'
        self.extracted_dir = self.base_dir / 'extracted'
        self.raw_html_dir.mkdir(parents=True, exist_ok=True)
        self.extracted_dir.mkdir(parents=True, exist_ok=True)
        
        # Initialize components
        self.collector = RawHTMLCollector(delay_range=(0.5, 1.0), max_workers=4)
        self.extractor = ProductExtractor()
        self.s3_uploader = get_s3_uploader()
        
        logger.info(f"Container {self.container_id} initialized")
        logger.info(f"Processing URLs {self.chunk_start} to {self.chunk_start + self.chunk_size}")
    
    def load_urls(self):
        """Load URLs from the embedded file"""
        # First try the environment variable path
        urls_file_path = os.environ.get('URLS_FILE', '/app/urls_chunk.txt')
        urls_file = Path(urls_file_path)
        
        # If that doesn't exist, try the data directory
        if not urls_file.exists():
            urls_file = Path('/app/data/urls_chunk.txt')
        
        # If no chunk file exists, load from config
        if not urls_file.exists():
            config_path = '/app/docker/config.json'
            if os.path.exists(config_path):
                with open(config_path, 'r') as f:
                    config = json.load(f)
                    urls = config['urls'][self.chunk_start:self.chunk_start + self.chunk_size]
            else:
                logger.error("No URLs file found!")
                return []
        else:
            with open(urls_file, 'r') as f:
                urls = [line.strip() for line in f if line.strip()]
        
        logger.info(f"Loaded {len(urls)} URLs from {urls_file}")
        return urls
    
    def save_raw_html(self, url, html_content, product_id):
        """Save raw HTML with product ID as identifier"""
        filename = f"{product_id}.html.gz"
        filepath = self.raw_html_dir / filename
        
        with gzip.open(filepath, 'wt', encoding='utf-8') as f:
            f.write(html_content)
        
        return filepath
    
    def save_extracted_data(self, product_id, data):
        """Save extracted product data as JSON"""
        filename = f"{product_id}.json"
        filepath = self.extracted_dir / filename
        
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        
        return filepath
    
    def process_single_url(self, url):
        """Process a single URL: fetch, save HTML, extract data"""
        try:
            # Extract product ID from URL
            product_id = self.extract_product_id(url)
            
            logger.info(f"Processing {product_id}: {url}")
            
            # Fetch HTML
            result = self.collector.fetch_single_html(url)
            
            if result.status_code != 200 or not result.html_content:
                logger.error(f"Failed to fetch {product_id}: Status {result.status_code}")
                return False
            
            # Save raw HTML
            html_path = self.save_raw_html(url, result.html_content, product_id)
            logger.info(f"Saved HTML: {html_path}")
            
            # Upload HTML to S3 if enabled
            self.s3_uploader.upload_raw_html(product_id, html_path)
            
            # Extract product data
            extracted_data = self.extractor.extract(result.html_content, url)
            extracted_data['extraction_metadata'] = {
                'container_id': self.container_id,
                'extraction_time': datetime.now().isoformat(),
                'html_size_bytes': len(result.html_content),
                'product_id': product_id
            }
            
            # Save extracted data
            json_path = self.save_extracted_data(product_id, extracted_data)
            logger.info(f"Saved extracted data: {json_path}")
            
            # Upload JSON to S3 if enabled
            self.s3_uploader.upload_extracted_data(product_id, json_path)
            
            return True
            
        except Exception as e:
            logger.error(f"Error processing {url}: {str(e)}")
            return False
    
    def extract_product_id(self, url):
        """Extract product ID from URL"""
        # Pattern: /id-f_10001073/
        if '/id-f_' in url:
            parts = url.split('/id-f_')[1]
            product_id = 'f_' + parts.split('/')[0]
            return product_id
        else:
            # Fallback to URL hash
            return hashlib.md5(url.encode()).hexdigest()[:10]
    
    def generate_summary(self, stats):
        """Generate processing summary"""
        summary = {
            'container_id': self.container_id,
            'processing_time': datetime.now().isoformat(),
            'urls_processed': stats['total'],
            'successful': stats['success'],
            'failed': stats['failed'],
            'chunk_range': f"{self.chunk_start}-{self.chunk_start + self.chunk_size}",
            'success_rate': f"{(stats['success'] / stats['total'] * 100):.1f}%" if stats['total'] > 0 else "0%"
        }
        
        summary_path = self.base_dir / f'container_{self.container_id}_summary.json'
        with open(summary_path, 'w') as f:
            json.dump(summary, f, indent=2)
        
        return summary
    
    def run(self):
        """Main processing loop"""
        start_time = time.time()
        
        # Load URLs
        urls = self.load_urls()
        
        # Send start notification
        notify_start(len(urls))
        
        # Process statistics
        stats = {'total': len(urls), 'success': 0, 'failed': 0}
        
        # Process each URL
        for i, url in enumerate(urls, 1):
            logger.info(f"Progress: {i}/{len(urls)} ({i/len(urls)*100:.1f}%)")
            
            if self.process_single_url(url):
                stats['success'] += 1
            else:
                stats['failed'] += 1
            
            # Progress notifications
            if i % 100 == 0:
                self.save_checkpoint(i, stats)
                notify_progress(i, len(urls), stats['success'], stats['failed'])
            
            # Milestone notifications
            if i in [500, 1000, 2500, 5000]:
                notify_milestone(i)
        
        # Generate final summary
        elapsed_time = time.time() - start_time
        summary = self.generate_summary(stats)
        summary['elapsed_seconds'] = elapsed_time
        summary['urls_per_minute'] = (stats['total'] / elapsed_time * 60) if elapsed_time > 0 else 0
        
        # Save final summary
        summary_path = self.base_dir / f'container_{self.container_id}_summary.json'
        with open(summary_path, 'w') as f:
            json.dump(summary, f, indent=2)
        
        # Upload summary to S3 if enabled
        self.s3_uploader.upload_summary(summary_path)
        
        # Send completion notification
        notify_complete(summary)
        
        logger.info(f"Container {self.container_id} completed!")
        logger.info(f"Processed: {stats['total']}, Success: {stats['success']}, Failed: {stats['failed']}")
        logger.info(f"Time: {elapsed_time:.1f}s, Rate: {summary['urls_per_minute']:.1f} URLs/min")
    
    def save_checkpoint(self, processed_count, stats):
        """Save processing checkpoint"""
        checkpoint = {
            'container_id': self.container_id,
            'timestamp': datetime.now().isoformat(),
            'processed': processed_count,
            'stats': stats
        }
        
        checkpoint_path = self.base_dir / f'container_{self.container_id}_checkpoint.json'
        with open(checkpoint_path, 'w') as f:
            json.dump(checkpoint, f, indent=2)

if __name__ == "__main__":
    processor = ContainerProcessor()
    processor.run()