#!/usr/bin/env python3
"""
Local test runner for ghost protocol processing
Tests the system without Docker
"""

import os
import sys
import json
import time
from pathlib import Path

# Add src to path
sys.path.append('src')

from src.parsers.html_collector import RawHTMLCollector
from src.extractors.product_extractor import ProductExtractor

def test_local_processing():
    """Test processing locally without Docker"""
    
    print("=== Local Ghost Protocol Test ===")
    
    # Setup directories
    test_dir = Path('local_test_data')
    test_dir.mkdir(exist_ok=True)
    
    raw_html_dir = test_dir / 'raw_html'
    extracted_dir = test_dir / 'extracted'
    raw_html_dir.mkdir(exist_ok=True)
    extracted_dir.mkdir(exist_ok=True)
    
    # Load test URLs
    chunk_file = 'test_chunks/urls_chunk_0001.txt'
    if not os.path.exists(chunk_file):
        print(f"Error: {chunk_file} not found. Run test setup first.")
        return False
    
    with open(chunk_file, 'r') as f:
        urls = [line.strip() for line in f if line.strip()]
    
    print(f"Testing with {len(urls)} URLs from {chunk_file}")
    
    # Initialize components
    collector = RawHTMLCollector(delay_range=(0.5, 1.0), max_workers=2)
    extractor = ProductExtractor()
    
    # Process URLs
    stats = {'total': len(urls), 'success': 0, 'failed': 0}
    
    for i, url in enumerate(urls, 1):
        print(f"\nProcessing {i}/{len(urls)}: {url}")
        
        try:
            # Extract product ID
            product_id = extract_product_id(url)
            
            # Fetch HTML
            result = collector.fetch_single_html(url)
            
            if result.status_code != 200 or not result.html_content:
                print(f"  ✗ Failed to fetch (Status: {result.status_code})")
                stats['failed'] += 1
                continue
            
            # Save raw HTML
            html_file = raw_html_dir / f"{product_id}.html"
            with open(html_file, 'w', encoding='utf-8') as f:
                f.write(result.html_content)
            print(f"  ✓ Saved HTML ({len(result.html_content):,} bytes)")
            
            # Extract product data
            extracted_data = extractor.extract(result.html_content, url)
            extracted_data['test_metadata'] = {
                'product_id': product_id,
                'html_size': len(result.html_content),
                'test_time': time.time()
            }
            
            # Save extracted data
            json_file = extracted_dir / f"{product_id}.json"
            with open(json_file, 'w') as f:
                json.dump(extracted_data, f, indent=2)
            
            print(f"  ✓ Extracted: {extracted_data.get('title', 'No title')}")
            if extracted_data.get('price'):
                print(f"    Price: {extracted_data['price']}")
            if extracted_data.get('materials'):
                print(f"    Materials: {', '.join(extracted_data['materials'][:3])}")
            
            stats['success'] += 1
            
        except Exception as e:
            print(f"  ✗ Error: {str(e)}")
            stats['failed'] += 1
    
    # Summary
    print(f"\n=== Test Complete ===")
    print(f"Total: {stats['total']}")
    print(f"Success: {stats['success']}")
    print(f"Failed: {stats['failed']}")
    print(f"Success rate: {stats['success']/stats['total']*100:.1f}%")
    
    print(f"\nResults saved to:")
    print(f"  HTML files: {raw_html_dir}")
    print(f"  JSON files: {extracted_dir}")
    
    # Show sample extracted data
    json_files = list(extracted_dir.glob('*.json'))
    if json_files:
        print(f"\nSample extracted data from {json_files[0].name}:")
        with open(json_files[0]) as f:
            sample = json.load(f)
        
        for key in ['title', 'price', 'description', 'materials', 'category']:
            if key in sample and sample[key]:
                value = sample[key]
                if isinstance(value, list):
                    value = ', '.join(value[:3])
                print(f"  {key}: {value}")
    
    return stats['success'] > 0

def extract_product_id(url):
    """Extract product ID from URL"""
    if '/id-f_' in url:
        parts = url.split('/id-f_')[1]
        product_id = 'f_' + parts.split('/')[0]
        return product_id
    else:
        import hashlib
        return hashlib.md5(url.encode()).hexdigest()[:10]

if __name__ == "__main__":
    success = test_local_processing()
    sys.exit(0 if success else 1)