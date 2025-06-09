from typing import Dict, List, Tuple, Set, Any
from collections import Counter, defaultdict
import numpy as np
from itertools import combinations
import re

class PatternDiscoveryEngine:
    def __init__(self):
        self.co_occurrence_threshold = 0.05
        self.min_pattern_frequency = 10
        
    def discover_co_occurrences(self, metadata_list: List[Dict]) -> Dict[str, List[Tuple[str, float]]]:
        term_documents = defaultdict(set)
        doc_terms = []
        
        for i, metadata in enumerate(metadata_list):
            terms = set(metadata.get('extracted_terms', []))
            doc_terms.append(terms)
            for term in terms:
                term_documents[term].add(i)
        
        co_occurrences = defaultdict(Counter)
        
        for doc_idx, terms in enumerate(doc_terms):
            for term1, term2 in combinations(sorted(terms), 2):
                co_occurrences[term1][term2] += 1
                co_occurrences[term2][term1] += 1
        
        results = {}
        total_docs = len(metadata_list)
        
        for term, partners in co_occurrences.items():
            term_freq = len(term_documents[term])
            significant_partners = []
            
            for partner, co_count in partners.most_common(20):
                partner_freq = len(term_documents[partner])
                expected_freq = (term_freq * partner_freq) / total_docs
                
                if co_count > expected_freq * 1.5 and co_count >= self.min_pattern_frequency:
                    lift = co_count / expected_freq if expected_freq > 0 else 0
                    significant_partners.append((partner, lift))
            
            if significant_partners:
                results[term] = sorted(significant_partners, key=lambda x: x[1], reverse=True)[:10]
        
        return results
    
    def discover_sequential_patterns(self, metadata_list: List[Dict]) -> Dict[str, int]:
        sequence_counter = Counter()
        
        for metadata in metadata_list:
            segments = metadata.get('path_segments', [])
            for i in range(len(segments) - 1):
                bigram = f"{segments[i]} -> {segments[i+1]}"
                sequence_counter[bigram] += 1
                
                if i < len(segments) - 2:
                    trigram = f"{segments[i]} -> {segments[i+1]} -> {segments[i+2]}"
                    sequence_counter[trigram] += 1
        
        return {seq: count for seq, count in sequence_counter.items() 
                if count >= self.min_pattern_frequency}
    
    def discover_linguistic_patterns(self, metadata_list: List[Dict]) -> Dict[str, Any]:
        patterns = {
            'adjective_noun_patterns': Counter(),
            'material_patterns': Counter(),
            'style_patterns': Counter(),
            'origin_patterns': Counter(),
            'compound_patterns': Counter()
        }
        
        material_keywords = {'wood', 'metal', 'glass', 'brass', 'bronze', 'steel', 'iron', 
                           'walnut', 'oak', 'mahogany', 'marble', 'leather', 'fabric', 'crystal'}
        style_keywords = {'modern', 'vintage', 'antique', 'contemporary', 'traditional', 
                         'mid-century', 'art-deco', 'victorian', 'industrial', 'rustic'}
        origin_keywords = {'italian', 'french', 'danish', 'american', 'english', 'german', 
                          'swedish', 'spanish', 'chinese', 'japanese'}
        
        for metadata in metadata_list:
            description = metadata.get('item_description', '')
            terms = metadata.get('extracted_terms', [])
            hyphenated = metadata.get('hyphenated_terms', [])
            
            patterns['compound_patterns'].update(hyphenated)
            
            terms_lower = [t.lower() for t in terms]
            for i, term in enumerate(terms_lower):
                if term in material_keywords:
                    patterns['material_patterns'][term] += 1
                    if i > 0:
                        patterns['adjective_noun_patterns'][f"{terms_lower[i-1]} {term}"] += 1
                
                if term in style_keywords:
                    patterns['style_patterns'][term] += 1
                
                if term in origin_keywords:
                    patterns['origin_patterns'][term] += 1
        
        return {
            key: dict(counter.most_common(50)) 
            for key, counter in patterns.items() 
            if counter
        }
    
    def discover_hierarchical_patterns(self, metadata_list: List[Dict]) -> Dict[str, Any]:
        hierarchy_patterns = defaultdict(lambda: defaultdict(Counter))
        depth_patterns = defaultdict(list)
        
        for metadata in metadata_list:
            hierarchy = metadata.get('category_hierarchy', [])
            depth = metadata.get('depth_level', 0)
            
            depth_patterns[depth].append(hierarchy)
            
            for i, category in enumerate(hierarchy):
                if i < len(hierarchy) - 1:
                    parent = category
                    child = hierarchy[i + 1]
                    hierarchy_patterns[i][parent][child] += 1
        
        hierarchy_summary = {}
        for level, parent_children in hierarchy_patterns.items():
            level_summary = {}
            for parent, children in parent_children.items():
                level_summary[parent] = {
                    'total_children': len(children),
                    'top_children': children.most_common(10),
                    'child_diversity': len(children) / sum(children.values()) if children else 0
                }
            hierarchy_summary[f'level_{level}'] = level_summary
        
        return {
            'hierarchy_patterns': hierarchy_summary,
            'depth_distribution': {depth: len(items) for depth, items in depth_patterns.items()},
            'average_depth': np.mean([m.get('depth_level', 0) for m in metadata_list])
        }
    
    def discover_numeric_patterns(self, metadata_list: List[Dict]) -> Dict[str, Any]:
        year_counter = Counter()
        measurement_patterns = Counter()
        numeric_contexts = defaultdict(Counter)
        
        year_pattern = re.compile(r'\b(1[0-9]{3}|20[0-9]{2})s?\b')
        measurement_pattern = re.compile(r'\b\d+(?:\.\d+)?[\s-]*(inch|cm|mm|ft|meter|x)\b', re.IGNORECASE)
        
        for metadata in metadata_list:
            numeric_values = metadata.get('numeric_values', [])
            description = metadata.get('item_description', '')
            
            for num in numeric_values:
                if year_pattern.match(str(num)):
                    decade = (int(str(num)[:4]) // 10) * 10
                    year_counter[f"{decade}s"] += 1
            
            measurements = measurement_pattern.findall(description)
            measurement_patterns.update(measurements)
            
            terms = metadata.get('extracted_terms', [])
            for i, term in enumerate(terms):
                if any(char.isdigit() for char in term):
                    context = []
                    if i > 0:
                        context.append(terms[i-1])
                    if i < len(terms) - 1:
                        context.append(terms[i+1])
                    if context:
                        numeric_contexts[term].update(context)
        
        return {
            'year_distribution': dict(year_counter.most_common()),
            'measurement_patterns': dict(measurement_patterns.most_common(20)),
            'numeric_contexts': {
                num: dict(contexts.most_common(5)) 
                for num, contexts in numeric_contexts.items() 
                if sum(contexts.values()) >= 5
            }
        }
    
    def generate_comprehensive_report(self, metadata_list: List[Dict]) -> Dict[str, Any]:
        print("Discovering co-occurrence patterns...")
        co_occurrences = self.discover_co_occurrences(metadata_list)
        
        print("Discovering sequential patterns...")
        sequential = self.discover_sequential_patterns(metadata_list)
        
        print("Discovering linguistic patterns...")
        linguistic = self.discover_linguistic_patterns(metadata_list)
        
        print("Discovering hierarchical patterns...")
        hierarchical = self.discover_hierarchical_patterns(metadata_list)
        
        print("Discovering numeric patterns...")
        numeric = self.discover_numeric_patterns(metadata_list)
        
        return {
            'total_urls_analyzed': len(metadata_list),
            'co_occurrence_patterns': co_occurrences,
            'sequential_patterns': sequential,
            'linguistic_patterns': linguistic,
            'hierarchical_patterns': hierarchical,
            'numeric_patterns': numeric,
            'discovery_summary': {
                'unique_co_occurrence_pairs': len(co_occurrences),
                'sequential_patterns_found': len(sequential),
                'unique_materials': len(linguistic.get('material_patterns', {})),
                'unique_styles': len(linguistic.get('style_patterns', {})),
                'unique_origins': len(linguistic.get('origin_patterns', {})),
                'hierarchy_depth': hierarchical.get('average_depth', 0)
            }
        }