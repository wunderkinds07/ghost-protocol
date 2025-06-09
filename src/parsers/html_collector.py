import requests
import time
import json
import gzip
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
import hashlib
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm
import random
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from datetime import datetime

@dataclass
class RawHTMLData:
    url: str
    status_code: int
    html_content: str = ""
    content_length: int = 0
    response_headers: Dict[str, str] = None
    fetch_timestamp: str = ""
    error: str = ""
    
    def __post_init__(self):
        if self.response_headers is None:
            self.response_headers = {}
        if not self.fetch_timestamp:
            self.fetch_timestamp = datetime.now().isoformat()
        if self.html_content:
            self.content_length = len(self.html_content)
    
    def to_dict(self) -> Dict:
        return {
            'url': self.url,
            'status_code': self.status_code,
            'content_length': self.content_length,
            'response_headers': self.response_headers,
            'fetch_timestamp': self.fetch_timestamp,
            'error': self.error,
            # HTML content stored separately for efficiency
        }
    
    def get_filename(self) -> str:
        """Generate a safe filename for the HTML content"""
        url_hash = hashlib.md5(self.url.encode()).hexdigest()[:12]
        # Extract ID from URL if available
        url_id = ""
        if "/id-f_" in self.url:
            try:
                url_id = self.url.split("/id-f_")[1].split("/")[0]
            except:
                pass
        
        if url_id:
            return f"{url_id}_{url_hash}.html"
        else:
            return f"{url_hash}.html"

class RawHTMLCollector:
    def __init__(self, delay_range: Tuple[float, float] = (0.5, 1.0), max_workers: int = 5):
        self.delay_range = delay_range
        self.max_workers = max_workers
        self.session = self._create_session()
        
    def _create_session(self) -> requests.Session:
        """Create a session with retry strategy and headers"""
        session = requests.Session()
        
        # Retry strategy
        retry_strategy = Retry(
            total=3,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504],
        )
        
        adapter = HTTPAdapter(max_retries=retry_strategy)
        session.mount("http://", adapter)
        session.mount("https://", adapter)
        
        # Headers to look like a real browser
        session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        })
        
        return session
    
    def _random_delay(self):
        """Add random delay to avoid overwhelming the server"""
        delay = random.uniform(*self.delay_range)
        time.sleep(delay)
    
    def fetch_single_html(self, url: str) -> RawHTMLData:
        """Fetch raw HTML for a single URL"""
        html_data = RawHTMLData(url=url, status_code=0)
        
        try:
            # Add random delay
            self._random_delay()
            
            # Fetch the page
            response = self.session.get(url, timeout=30)
            html_data.status_code = response.status_code
            html_data.response_headers = dict(response.headers)
            
            if response.status_code == 200:
                html_data.html_content = response.text
                html_data.content_length = len(html_data.html_content)
            else:
                html_data.error = f"HTTP {response.status_code}"
                
        except requests.exceptions.RequestException as e:
            html_data.error = f"Request error: {str(e)}"
        except Exception as e:
            html_data.error = f"Fetch error: {str(e)}"
        
        return html_data
    
    def fetch_html_batch(self, urls: List[str], max_workers: int = None) -> List[RawHTMLData]:
        """Fetch raw HTML for multiple URLs concurrently"""
        if max_workers is None:
            max_workers = self.max_workers
        
        results = []
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all tasks
            future_to_url = {executor.submit(self.fetch_single_html, url): url for url in urls}
            
            # Process completed tasks with progress bar
            with tqdm(total=len(urls), desc="Fetching HTML") as pbar:
                for future in as_completed(future_to_url):
                    result = future.result()
                    results.append(result)
                    pbar.update(1)
                    
                    # Log progress occasionally
                    if len(results) % 100 == 0:
                        success_rate = len([r for r in results if r.status_code == 200]) / len(results) * 100
                        avg_size = sum(r.content_length for r in results if r.content_length) / max(len([r for r in results if r.content_length]), 1)
                        print(f"\nProcessed {len(results)} URLs. Success: {success_rate:.1f}%, Avg size: {avg_size/1024:.1f}KB")
        
        return results
    
    def save_html_collection(self, results: List[RawHTMLData], batch_name: str, 
                           compress: bool = True, separate_files: bool = True):
        """Save HTML collection with multiple storage options"""
        
        # Create output directories
        base_dir = Path("data/raw_html") / batch_name
        base_dir.mkdir(parents=True, exist_ok=True)
        
        metadata_list = []
        successful_results = [r for r in results if r.status_code == 200 and r.html_content]
        
        print(f"\nSaving {len(successful_results)} HTML files...")
        
        if separate_files:
            # Save each HTML as separate file
            html_dir = base_dir / "html_files"
            html_dir.mkdir(exist_ok=True)
            
            for result in tqdm(successful_results, desc="Saving HTML files"):
                filename = result.get_filename()
                file_path = html_dir / filename
                
                if compress:
                    # Save as gzipped file
                    with gzip.open(f"{file_path}.gz", 'wt', encoding='utf-8') as f:
                        f.write(result.html_content)
                    result.local_file = f"{filename}.gz"
                else:
                    # Save as plain text
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(result.html_content)
                    result.local_file = filename
                
                # Add to metadata
                metadata = result.to_dict()
                metadata['local_file'] = result.local_file
                metadata_list.append(metadata)
        
        else:
            # Save all HTML in single archive
            archive_path = base_dir / f"html_archive.json"
            if compress:
                archive_path = base_dir / f"html_archive.json.gz"
            
            html_archive = {}
            for result in successful_results:
                html_archive[result.url] = {
                    'html_content': result.html_content,
                    'metadata': result.to_dict()
                }
                metadata_list.append(result.to_dict())
            
            if compress:
                with gzip.open(archive_path, 'wt', encoding='utf-8') as f:
                    json.dump(html_archive, f, indent=2)
            else:
                with open(archive_path, 'w', encoding='utf-8') as f:
                    json.dump(html_archive, f, indent=2)
        
        # Save metadata separately
        metadata_path = base_dir / "metadata.json"
        with open(metadata_path, 'w', encoding='utf-8') as f:
            json.dump(metadata_list, f, indent=2)
        
        # Save collection summary
        self._save_collection_summary(results, base_dir / "collection_summary.json")
        
        print(f"HTML collection saved to: {base_dir}")
        print(f"- Metadata: {metadata_path}")
        print(f"- Summary: {base_dir / 'collection_summary.json'}")
        if separate_files:
            print(f"- HTML files: {base_dir / 'html_files'} ({len(successful_results)} files)")
        else:
            print(f"- HTML archive: {archive_path}")
    
    def _save_collection_summary(self, results: List[RawHTMLData], summary_path: Path):
        """Save collection summary statistics"""
        total_urls = len(results)
        successful = [r for r in results if r.status_code == 200]
        failed = [r for r in results if r.status_code != 200]
        
        # Size statistics
        sizes = [r.content_length for r in successful if r.content_length > 0]
        total_size = sum(sizes)
        avg_size = total_size / len(sizes) if sizes else 0
        
        # Error analysis
        error_types = {}
        for result in failed:
            if result.error:
                error_type = result.error.split(':')[0]
                error_types[error_type] = error_types.get(error_type, 0) + 1
            else:
                error_type = f"HTTP_{result.status_code}"
                error_types[error_type] = error_types.get(error_type, 0) + 1
        
        # Status code distribution
        status_codes = {}
        for result in results:
            status_codes[result.status_code] = status_codes.get(result.status_code, 0) + 1
        
        summary = {
            'collection_info': {
                'total_urls': total_urls,
                'successful_fetches': len(successful),
                'failed_fetches': len(failed),
                'success_rate': (len(successful) / total_urls * 100) if total_urls > 0 else 0,
                'collection_timestamp': datetime.now().isoformat()
            },
            'content_statistics': {
                'total_html_size_bytes': total_size,
                'total_html_size_mb': total_size / (1024 * 1024),
                'average_page_size_bytes': int(avg_size),
                'average_page_size_kb': avg_size / 1024,
                'largest_page_bytes': max(sizes) if sizes else 0,
                'smallest_page_bytes': min(sizes) if sizes else 0
            },
            'status_code_distribution': status_codes,
            'error_analysis': error_types,
            'processing_config': {
                'delay_range': self.delay_range,
                'max_workers': self.max_workers
            }
        }
        
        with open(summary_path, 'w') as f:
            json.dump(summary, f, indent=2)
        
        # Print summary
        print(f"\n{'='*50}")
        print(f"COLLECTION SUMMARY")
        print(f"{'='*50}")
        print(f"Total URLs: {total_urls}")
        print(f"Successful: {len(successful)} ({summary['collection_info']['success_rate']:.1f}%)")
        print(f"Failed: {len(failed)}")
        print(f"Total HTML size: {summary['content_statistics']['total_html_size_mb']:.1f} MB")
        print(f"Average page size: {summary['content_statistics']['average_page_size_kb']:.1f} KB")
        
        if error_types:
            print(f"\nErrors:")
            for error, count in sorted(error_types.items(), key=lambda x: x[1], reverse=True):
                print(f"  {error}: {count}")

def load_urls_sample(file_path: str, sample_size: int) -> List[str]:
    """Load a sample of URLs from the dataset"""
    with open(file_path, 'r') as f:
        urls = [line.strip() for line in f if line.strip()]
    
    return urls[:sample_size]