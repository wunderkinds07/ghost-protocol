"""
Product data extractor for 1stDibs HTML pages
Extracts core product information, specifications, pricing, and image URLs
"""

import json
import re
from bs4 import BeautifulSoup
from typing import Dict, List, Any
import logging

logger = logging.getLogger(__name__)

class ProductExtractor:
    def __init__(self):
        self.required_fields = [
            'title', 'product_id', 'category', 'price', 
            'dimensions', 'materials', 'images'
        ]
    
    def extract(self, html_content: str, url: str) -> Dict[str, Any]:
        """Extract all product data from HTML"""
        soup = BeautifulSoup(html_content, 'lxml')
        
        # Initialize result structure
        result = {
            'url': url,
            'extraction_status': 'success',
            'data': {}
        }
        
        try:
            # Extract structured data from JSON-LD
            json_ld_data = self._extract_json_ld(soup)
            
            # Extract product information with individual error handling
            product_data = {}
            
            try:
                product_data['product_info'] = self._extract_product_info(soup, json_ld_data)
            except Exception as e:
                logger.error(f"Error extracting product info: {e}")
                product_data['product_info'] = {}
            
            try:
                product_data['specifications'] = self._extract_specifications(soup, json_ld_data)
            except Exception as e:
                logger.error(f"Error extracting specifications: {e}")
                product_data['specifications'] = {}
            
            try:
                product_data['pricing'] = self._extract_pricing(soup, json_ld_data)
            except Exception as e:
                logger.error(f"Error extracting pricing: {e}")
                product_data['pricing'] = {}
            
            try:
                product_data['images'] = self._extract_images(soup, json_ld_data)
            except Exception as e:
                logger.error(f"Error extracting images: {e}")
                product_data['images'] = []
            
            try:
                product_data['category_breadcrumb'] = self._extract_breadcrumb(soup)
            except Exception as e:
                logger.error(f"Error extracting breadcrumb: {e}")
                product_data['category_breadcrumb'] = []
            
            result['data'] = product_data
            
        except Exception as e:
            logger.error(f"Extraction error for {url}: {str(e)}")
            result['extraction_status'] = 'failed'
            result['error'] = str(e)
        
        return result
    
    def _extract_json_ld(self, soup: BeautifulSoup) -> Dict:
        """Extract JSON-LD structured data"""
        json_ld = {}
        
        scripts = soup.find_all('script', type='application/ld+json')
        for script in scripts:
            try:
                # Parse the JSON content
                content = script.string
                if content:
                    data = json.loads(content)
                    
                    # Handle array of objects
                    if isinstance(data, list):
                        for item in data:
                            if isinstance(item, dict):
                                if item.get('@type') == 'Product':
                                    json_ld['product'] = item
                                elif item.get('@type') == 'BreadcrumbList':
                                    json_ld['breadcrumb'] = item
                    # Handle single object
                    elif isinstance(data, dict):
                        if data.get('@type') == 'Product':
                            json_ld['product'] = data
                        elif data.get('@type') == 'BreadcrumbList':
                            json_ld['breadcrumb'] = data
            except Exception as e:
                logger.debug(f"Error parsing JSON-LD: {e}")
                continue
        
        return json_ld
    
    def _extract_product_info(self, soup: BeautifulSoup, json_ld: Dict) -> Dict:
        """Extract core product information"""
        info = {}
        
        # From JSON-LD
        if 'product' in json_ld:
            product = json_ld['product']
            info['title'] = product.get('name', '')
            info['description'] = product.get('description', '')
            info['product_id'] = product.get('sku', '')
            
            # Handle brand
            brand = product.get('brand', {})
            if isinstance(brand, dict):
                info['brand'] = brand.get('name', '')
            
            # Handle availability from offers array
            offers = product.get('offers', [])
            if isinstance(offers, list) and offers:
                info['availability'] = offers[0].get('availability', '')
            elif isinstance(offers, dict):
                info['availability'] = offers.get('availability', '')
        
        # From HTML as fallback
        if not info.get('title'):
            title_elem = soup.find('h1', class_='headline-3')
            if title_elem:
                info['title'] = title_elem.get_text(strip=True)
        
        if not info.get('product_id'):
            # Extract from URL or page
            url_match = re.search(r'/id-(f_\d+)/', soup.find('link', {'rel': 'canonical'})['href'] if soup.find('link', {'rel': 'canonical'}) else '')
            if url_match:
                info['product_id'] = url_match.group(1)
        
        return info
    
    def _extract_specifications(self, soup: BeautifulSoup, json_ld: Dict) -> Dict:
        """Extract product specifications"""
        specs = {}
        
        # From JSON-LD
        if 'product' in json_ld:
            product = json_ld['product']
            
            # Period/Date
            if 'productionDate' in product:
                specs['period'] = product['productionDate']
            
            # Category
            if 'category' in product:
                specs['category'] = product['category']
            
            # Condition
            if 'itemCondition' in product:
                condition = product['itemCondition']
                if isinstance(condition, str):
                    specs['condition'] = condition.replace('http://schema.org/', '')
        
        # Extract dimensions from description (common pattern)
        if 'product' in json_ld:
            description = json_ld['product'].get('description', '')
            # Look for pattern like "Height 34 1/2 x width 48 inches"
            import re
            dim_match = re.search(r'Height\s*([\d\s/]+)\s*x\s*width\s*([\d\s/]+)\s*inches', description, re.IGNORECASE)
            if dim_match:
                specs['dimensions'] = {
                    'height': dim_match.group(1).strip() + ' inches',
                    'width': dim_match.group(2).strip() + ' inches'
                }
        
        # Materials from description
        if not specs.get('materials') and 'product' in json_ld:
            desc = json_ld['product'].get('description', '').lower()
            # Common materials
            materials = []
            material_keywords = ['walnut', 'oak', 'mahogany', 'brass', 'bronze', 'glass', 'marble', 
                               'ceramic', 'porcelain', 'silver', 'gold', 'steel', 'iron', 'wood']
            for material in material_keywords:
                if material in desc:
                    materials.append(material.capitalize())
            if materials:
                specs['materials'] = ', '.join(materials)
        
        # Extract from HTML as fallback
        details_section = soup.find('div', class_='product-details')
        if details_section:
            for item in details_section.find_all('li'):
                text = item.get_text(strip=True)
                if 'Materials' in text and not specs.get('materials'):
                    specs['materials'] = text.replace('Materials and Techniques', '').strip()
                elif 'Place of Origin' in text and not specs.get('origin'):
                    specs['origin'] = text.replace('Place of Origin', '').strip()
                elif 'Period' in text and not specs.get('period'):
                    specs['period'] = text.replace('Period', '').strip()
                elif 'Style' in text and not specs.get('style'):
                    specs['style'] = text.replace('Style', '').strip()
        
        return specs
    
    def _extract_pricing(self, soup: BeautifulSoup, json_ld: Dict) -> Dict:
        """Extract pricing information"""
        pricing = {}
        
        # From JSON-LD
        if 'product' in json_ld:
            offers = json_ld['product'].get('offers', [])
            
            # Handle array of offers (multiple currencies)
            if isinstance(offers, list):
                multi_currency = {}
                for offer in offers:
                    if isinstance(offer, dict):
                        currency = offer.get('priceCurrency', '')
                        price = offer.get('price', '')
                        if currency and price:
                            multi_currency[currency] = price
                            # Set USD as primary if available
                            if currency == 'USD':
                                pricing['currency'] = 'USD'
                                pricing['price'] = str(price)
                
                if multi_currency:
                    pricing['multi_currency'] = multi_currency
            
            # Handle single offer
            elif isinstance(offers, dict):
                pricing['currency'] = offers.get('priceCurrency', 'USD')
                pricing['price'] = str(offers.get('price', ''))
        
        # Extract from HTML as fallback
        if not pricing.get('price'):
            price_elements = soup.find_all('span', {'data-cy': re.compile('price-.*')})
            currencies = {}
            for elem in price_elements:
                currency_match = re.search(r'price-(.+)', elem.get('data-cy', ''))
                if currency_match:
                    currency = currency_match.group(1).upper()
                    currencies[currency] = elem.get_text(strip=True)
            
            if currencies:
                pricing['multi_currency'] = currencies
                if 'USD' in currencies:
                    pricing['price'] = currencies['USD']
                    pricing['currency'] = 'USD'
        
        return pricing
    
    def _extract_images(self, soup: BeautifulSoup, json_ld: Dict) -> List[str]:
        """Extract all product image URLs"""
        images = []
        
        # From JSON-LD
        if 'product' in json_ld:
            json_images = json_ld['product'].get('image', [])
            if isinstance(json_images, list):
                # Extract URLs from image objects
                for img in json_images:
                    if isinstance(img, dict):
                        # Extract contentUrl from ImageObject
                        content_url = img.get('contentUrl', '')
                        if content_url:
                            # Remove query parameters to get master image
                            base_url = content_url.split('?')[0]
                            images.append(base_url)
                    elif isinstance(img, str):
                        images.append(img)
            elif isinstance(json_images, str):
                images.append(json_images)
        
        # From HTML image elements as fallback
        if not images:
            img_container = soup.find('div', class_='product-images')
            if img_container:
                for img in img_container.find_all('img'):
                    src = img.get('src') or img.get('data-src')
                    if src and 'master.jpg' in src:
                        images.append(src.split('?')[0])
        
        # Remove duplicates while preserving order
        seen = set()
        unique_images = []
        for img in images:
            if img not in seen:
                seen.add(img)
                unique_images.append(img)
        
        return unique_images
    
    def _extract_breadcrumb(self, soup: BeautifulSoup) -> List[str]:
        """Extract category breadcrumb"""
        breadcrumb = []
        
        # From JSON-LD breadcrumb if available
        scripts = soup.find_all('script', type='application/ld+json')
        for script in scripts:
            try:
                content = script.string
                if content:
                    data = json.loads(content)
                    # Handle array of objects
                    if isinstance(data, list):
                        for item in data:
                            if isinstance(item, dict) and item.get('@type') == 'BreadcrumbList':
                                items = item.get('itemListElement', [])
                                breadcrumb = [i.get('item', {}).get('name', '') for i in items if isinstance(i, dict)]
                                if breadcrumb:
                                    return breadcrumb
            except:
                pass
        
        # From HTML navigation
        nav = soup.find('nav', {'aria-label': 'breadcrumb'})
        if nav:
            links = nav.find_all('a')
            breadcrumb = [link.get_text(strip=True) for link in links]
        
        return breadcrumb