from typing import Dict, List, Tuple, Any
from urllib.parse import urlparse, unquote
import re
from dataclasses import dataclass, field
from collections import Counter

@dataclass
class URLMetadata:
    full_url: str
    domain: str
    path_segments: List[str]
    depth_level: int
    item_id: str = ""
    item_description: str = ""
    category_hierarchy: List[str] = field(default_factory=list)
    extracted_terms: List[str] = field(default_factory=list)
    numeric_values: List[str] = field(default_factory=list)
    hyphenated_terms: List[str] = field(default_factory=list)
    capitalized_terms: List[str] = field(default_factory=list)
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'full_url': self.full_url,
            'domain': self.domain,
            'path_segments': self.path_segments,
            'depth_level': self.depth_level,
            'item_id': self.item_id,
            'item_description': self.item_description,
            'category_hierarchy': self.category_hierarchy,
            'extracted_terms': self.extracted_terms,
            'numeric_values': self.numeric_values,
            'hyphenated_terms': self.hyphenated_terms,
            'capitalized_terms': self.capitalized_terms
        }

class URLParser:
    def __init__(self):
        self.id_pattern = re.compile(r'/id-f_(\d+)/$')
        self.numeric_pattern = re.compile(r'\b\d+\b')
        self.year_pattern = re.compile(r'\b(1[0-9]{3}|20[0-9]{2})s?\b')
        self.hyphenated_pattern = re.compile(r'\b[a-z]+(?:-[a-z]+)+\b', re.IGNORECASE)
        self.capitalized_pattern = re.compile(r'\b[A-Z][a-z]+\b')
        
    def parse_url(self, url: str) -> URLMetadata:
        parsed = urlparse(url.strip())
        path = parsed.path.strip('/')
        segments = [unquote(seg) for seg in path.split('/') if seg]
        
        metadata = URLMetadata(
            full_url=url,
            domain=parsed.netloc,
            path_segments=segments,
            depth_level=len(segments)
        )
        
        id_match = self.id_pattern.search(url)
        if id_match:
            metadata.item_id = id_match.group(1)
        
        if segments:
            if segments[0] == 'furniture':
                metadata.category_hierarchy = segments[:-1] if metadata.item_id else segments
            
            last_segment = segments[-2] if metadata.item_id and len(segments) > 1 else segments[-1]
            metadata.item_description = last_segment
            
            terms = []
            for segment in segments:
                if segment != metadata.item_id:
                    words = segment.replace('-', ' ').split()
                    terms.extend(words)
                    
                    nums = self.numeric_pattern.findall(segment)
                    metadata.numeric_values.extend(nums)
                    
                    years = self.year_pattern.findall(segment)
                    metadata.numeric_values.extend(years)
                    
                    hyphenated = self.hyphenated_pattern.findall(segment)
                    metadata.hyphenated_terms.extend(hyphenated)
                    
                    capitalized = self.capitalized_pattern.findall(segment)
                    metadata.capitalized_terms.extend(capitalized)
            
            metadata.extracted_terms = terms
        
        return metadata
    
    def parse_batch(self, urls: List[str], progress_callback=None) -> List[URLMetadata]:
        results = []
        for i, url in enumerate(urls):
            try:
                metadata = self.parse_url(url)
                results.append(metadata)
                if progress_callback and i % 1000 == 0:
                    progress_callback(i, len(urls))
            except Exception as e:
                print(f"Error parsing URL {url}: {e}")
        return results
    
    def extract_statistics(self, metadata_list: List[URLMetadata]) -> Dict[str, Any]:
        all_terms = []
        all_hyphenated = []
        all_numeric = []
        all_capitalized = []
        depth_distribution = Counter()
        category_distribution = Counter()
        
        for metadata in metadata_list:
            all_terms.extend(metadata.extracted_terms)
            all_hyphenated.extend(metadata.hyphenated_terms)
            all_numeric.extend(metadata.numeric_values)
            all_capitalized.extend(metadata.capitalized_terms)
            depth_distribution[metadata.depth_level] += 1
            
            if metadata.category_hierarchy:
                for i, cat in enumerate(metadata.category_hierarchy):
                    category_distribution[f"level_{i}:{cat}"] += 1
        
        return {
            'total_urls': len(metadata_list),
            'term_frequency': Counter(all_terms).most_common(100),
            'hyphenated_frequency': Counter(all_hyphenated).most_common(50),
            'numeric_frequency': Counter(all_numeric).most_common(50),
            'capitalized_frequency': Counter(all_capitalized).most_common(50),
            'depth_distribution': dict(depth_distribution),
            'category_distribution': dict(category_distribution.most_common(100))
        }