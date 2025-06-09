import requests
import time
import json
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, field
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm
import random
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

@dataclass
class HTMLPageData:
    url: str
    status_code: int
    title: str = ""
    description: str = ""
    price: str = ""
    dealer_name: str = ""
    item_details: Dict[str, str] = field(default_factory=dict)
    images: List[str] = field(default_factory=list)
    breadcrumbs: List[str] = field(default_factory=list)
    dimensions: str = ""
    materials: List[str] = field(default_factory=list)
    period: str = ""
    origin: str = ""
    condition: str = ""
    provenance: str = ""
    raw_text: str = ""
    error: str = ""
    
    def to_dict(self) -> Dict:
        return {
            'url': self.url,
            'status_code': self.status_code,
            'title': self.title,
            'description': self.description,
            'price': self.price,
            'dealer_name': self.dealer_name,
            'item_details': self.item_details,
            'images': self.images,
            'breadcrumbs': self.breadcrumbs,
            'dimensions': self.dimensions,
            'materials': self.materials,
            'period': self.period,
            'origin': self.origin,
            'condition': self.condition,
            'provenance': self.provenance,
            'raw_text': self.raw_text[:1000] if self.raw_text else "",  # Truncate for storage
            'error': self.error
        }

class HTMLParser:
    def __init__(self, delay_range: Tuple[float, float] = (1.0, 3.0), max_workers: int = 5):
        self.delay_range = delay_range
        self.max_workers = max_workers
        self.session = self._create_session()
        
        # Common selectors for 1stDibs (will need to be adjusted based on actual site structure)
        self.selectors = {
            'title': ['h1', '.item-title', '.product-title', '[data-test="item-title"]'],
            'price': ['.price', '.item-price', '[data-test="price"]', '.cost'],
            'dealer': ['.dealer-name', '.seller-name', '[data-test="dealer"]'],
            'description': ['.description', '.item-description', '[data-test="description"]'],
            'images': ['img[src*="product"]', '.item-image img', '.gallery img'],
            'breadcrumbs': ['.breadcrumb', '.breadcrumbs', 'nav ol li'],
            'details': ['.item-details', '.product-details', '.specifications']
        }
        
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
    
    def _extract_text_by_selectors(self, soup: BeautifulSoup, selectors: List[str]) -> str:
        """Try multiple selectors to find text content"""
        for selector in selectors:
            element = soup.select_one(selector)
            if element:
                return element.get_text(strip=True)
        return ""
    
    def _extract_images(self, soup: BeautifulSoup, base_url: str) -> List[str]:
        """Extract image URLs"""
        images = []
        for selector in self.selectors['images']:
            img_elements = soup.select(selector)
            for img in img_elements:
                src = img.get('src') or img.get('data-src')
                if src:
                    # Convert relative URLs to absolute
                    full_url = urljoin(base_url, src)
                    if full_url not in images:
                        images.append(full_url)
        return images[:10]  # Limit to first 10 images
    
    def _extract_breadcrumbs(self, soup: BeautifulSoup) -> List[str]:
        """Extract breadcrumb navigation"""
        breadcrumbs = []
        for selector in self.selectors['breadcrumbs']:
            elements = soup.select(selector)
            for element in elements:
                text = element.get_text(strip=True)
                if text and text not in breadcrumbs:
                    breadcrumbs.append(text)
        return breadcrumbs
    
    def _extract_item_details(self, soup: BeautifulSoup) -> Dict[str, str]:
        """Extract structured item details"""
        details = {}
        
        # Look for detail sections
        for selector in self.selectors['details']:
            detail_section = soup.select_one(selector)
            if detail_section:
                # Extract key-value pairs
                rows = detail_section.find_all(['tr', 'div', 'dl'])
                for row in rows:
                    # Try different patterns for key-value extraction
                    if row.name == 'tr':
                        cells = row.find_all(['td', 'th'])
                        if len(cells) >= 2:
                            key = cells[0].get_text(strip=True)
                            value = cells[1].get_text(strip=True)
                            if key and value:
                                details[key] = value
                    elif row.name == 'div':
                        # Look for label-value patterns
                        labels = row.find_all(class_=re.compile(r'label|key|title'))
                        values = row.find_all(class_=re.compile(r'value|content|text'))
                        if labels and values:
                            for label, value in zip(labels, values):
                                key = label.get_text(strip=True)
                                val = value.get_text(strip=True)
                                if key and val:
                                    details[key] = val
        
        return details
    
    def _extract_specific_fields(self, soup: BeautifulSoup, details: Dict[str, str]) -> Tuple[str, str, str, List[str], str]:
        """Extract specific fields from details and soup"""
        dimensions = ""
        period = ""
        origin = ""
        materials = []
        condition = ""
        
        # Extract from structured details
        for key, value in details.items():
            key_lower = key.lower()
            if any(dim_word in key_lower for dim_word in ['dimension', 'size', 'measurement']):
                dimensions = value
            elif any(period_word in key_lower for period_word in ['period', 'era', 'date', 'year']):
                period = value
            elif any(origin_word in key_lower for origin_word in ['origin', 'country', 'made in', 'provenance']):
                origin = value
            elif any(material_word in key_lower for material_word in ['material', 'medium', 'composition']):
                materials.append(value)
            elif any(condition_word in key_lower for condition_word in ['condition', 'state']):
                condition = value
        
        # Also search in general text for materials
        text_content = soup.get_text().lower()
        material_keywords = ['brass', 'bronze', 'wood', 'glass', 'marble', 'silver', 'gold', 'ceramic', 'leather', 'fabric']
        for material in material_keywords:
            if material in text_content and material not in materials:
                materials.append(material)
        
        return dimensions, period, origin, materials, condition
    
    def parse_single_url(self, url: str) -> HTMLPageData:
        """Parse a single URL and extract data"""
        page_data = HTMLPageData(url=url, status_code=0)
        
        try:
            # Add random delay
            self._random_delay()
            
            # Fetch the page
            response = self.session.get(url, timeout=30)
            page_data.status_code = response.status_code
            
            if response.status_code != 200:
                page_data.error = f"HTTP {response.status_code}"
                return page_data
            
            # Parse HTML
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Extract basic fields
            page_data.title = self._extract_text_by_selectors(soup, self.selectors['title'])
            page_data.price = self._extract_text_by_selectors(soup, self.selectors['price'])
            page_data.dealer_name = self._extract_text_by_selectors(soup, self.selectors['dealer'])
            page_data.description = self._extract_text_by_selectors(soup, self.selectors['description'])
            
            # Extract complex data
            page_data.images = self._extract_images(soup, url)
            page_data.breadcrumbs = self._extract_breadcrumbs(soup)
            page_data.item_details = self._extract_item_details(soup)
            
            # Extract specific fields
            dimensions, period, origin, materials, condition = self._extract_specific_fields(soup, page_data.item_details)
            page_data.dimensions = dimensions
            page_data.period = period
            page_data.origin = origin
            page_data.materials = materials
            page_data.condition = condition
            
            # Store raw text (truncated)
            page_data.raw_text = soup.get_text(separator=' ', strip=True)
            
        except requests.exceptions.RequestException as e:
            page_data.error = f"Request error: {str(e)}"
        except Exception as e:
            page_data.error = f"Parse error: {str(e)}"
        
        return page_data
    
    def parse_urls_batch(self, urls: List[str], max_workers: int = None) -> List[HTMLPageData]:
        """Parse multiple URLs concurrently"""
        if max_workers is None:
            max_workers = self.max_workers
        
        results = []
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all tasks
            future_to_url = {executor.submit(self.parse_single_url, url): url for url in urls}
            
            # Process completed tasks with progress bar
            with tqdm(total=len(urls), desc="Parsing URLs") as pbar:
                for future in as_completed(future_to_url):
                    result = future.result()
                    results.append(result)
                    pbar.update(1)
                    
                    # Log progress occasionally
                    if len(results) % 100 == 0:
                        success_rate = len([r for r in results if r.status_code == 200]) / len(results) * 100
                        print(f"\nProcessed {len(results)} URLs. Success rate: {success_rate:.1f}%")
        
        return results
    
    def save_results(self, results: List[HTMLPageData], filename: str):
        """Save parsing results to JSON file"""
        output_path = Path("data/parsed_html") / filename
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Convert to serializable format
        serializable_results = [result.to_dict() for result in results]
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(serializable_results, f, indent=2, ensure_ascii=False)
        
        print(f"Results saved to {output_path}")
        
        # Save summary statistics
        self._save_summary(results, output_path.parent / f"{output_path.stem}_summary.json")
    
    def _save_summary(self, results: List[HTMLPageData], summary_path: Path):
        """Save summary statistics"""
        total_urls = len(results)
        successful = len([r for r in results if r.status_code == 200])
        failed = total_urls - successful
        
        # Error analysis
        error_types = {}
        for result in results:
            if result.error:
                error_type = result.error.split(':')[0]
                error_types[error_type] = error_types.get(error_type, 0) + 1
        
        # Data completeness
        with_title = len([r for r in results if r.title])
        with_price = len([r for r in results if r.price])
        with_dealer = len([r for r in results if r.dealer_name])
        with_description = len([r for r in results if r.description])
        with_images = len([r for r in results if r.images])
        
        summary = {
            'total_urls': total_urls,
            'successful_parses': successful,
            'failed_parses': failed,
            'success_rate': (successful / total_urls * 100) if total_urls > 0 else 0,
            'error_types': error_types,
            'data_completeness': {
                'with_title': with_title,
                'with_price': with_price,
                'with_dealer': with_dealer,
                'with_description': with_description,
                'with_images': with_images
            },
            'completeness_rates': {
                'title_rate': (with_title / successful * 100) if successful > 0 else 0,
                'price_rate': (with_price / successful * 100) if successful > 0 else 0,
                'dealer_rate': (with_dealer / successful * 100) if successful > 0 else 0,
                'description_rate': (with_description / successful * 100) if successful > 0 else 0,
                'images_rate': (with_images / successful * 100) if successful > 0 else 0
            }
        }
        
        with open(summary_path, 'w') as f:
            json.dump(summary, f, indent=2)
        
        print(f"Summary saved to {summary_path}")
        print(f"Success rate: {summary['success_rate']:.1f}%")
        print(f"Data completeness rates: Title: {summary['completeness_rates']['title_rate']:.1f}%, "
              f"Price: {summary['completeness_rates']['price_rate']:.1f}%")