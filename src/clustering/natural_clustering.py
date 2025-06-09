from typing import Dict, List, Tuple, Set, Any
from collections import Counter, defaultdict
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.cluster import DBSCAN, AgglomerativeClustering
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.decomposition import PCA
import pandas as pd

class NaturalClusteringEngine:
    def __init__(self):
        self.min_cluster_size = 50
        self.similarity_threshold = 0.3
        
    def prepare_text_features(self, metadata_list: List[Dict]) -> Tuple[np.ndarray, List[str], TfidfVectorizer]:
        documents = []
        for metadata in metadata_list:
            terms = metadata.get('extracted_terms', [])
            hyphenated = metadata.get('hyphenated_terms', [])
            description = metadata.get('item_description', '')
            
            text = ' '.join(terms + hyphenated + [description])
            documents.append(text.lower())
        
        vectorizer = TfidfVectorizer(
            max_features=1000,
            min_df=5,
            max_df=0.8,
            ngram_range=(1, 2),
            stop_words='english'
        )
        
        tfidf_matrix = vectorizer.fit_transform(documents)
        feature_names = vectorizer.get_feature_names_out()
        
        return tfidf_matrix, feature_names, vectorizer
    
    def discover_content_clusters(self, metadata_list: List[Dict]) -> Dict[str, Any]:
        print("Preparing text features for clustering...")
        tfidf_matrix, feature_names, vectorizer = self.prepare_text_features(metadata_list)
        
        print("Computing similarity matrix...")
        similarity_matrix = cosine_similarity(tfidf_matrix[:5000])
        
        print("Performing DBSCAN clustering...")
        clustering = DBSCAN(eps=0.3, min_samples=10, metric='precomputed')
        distance_matrix = 1 - similarity_matrix
        distance_matrix = np.maximum(distance_matrix, 0)  # Ensure no negative values
        cluster_labels = clustering.fit_predict(distance_matrix)
        
        clusters = defaultdict(list)
        for idx, label in enumerate(cluster_labels):
            if label != -1:
                clusters[label].append(idx)
        
        cluster_analysis = {}
        for cluster_id, indices in clusters.items():
            if len(indices) >= self.min_cluster_size:
                cluster_terms = self._extract_cluster_characteristics(
                    indices, metadata_list, tfidf_matrix, feature_names
                )
                
                cluster_analysis[f"cluster_{cluster_id}"] = {
                    'size': len(indices),
                    'dominant_terms': cluster_terms['terms'][:20],
                    'common_categories': cluster_terms['categories'][:10],
                    'common_materials': cluster_terms['materials'][:10],
                    'common_styles': cluster_terms['styles'][:10],
                    'sample_urls': [metadata_list[i]['full_url'] for i in indices[:5]]
                }
        
        return {
            'content_clusters': cluster_analysis,
            'total_clusters': len(cluster_analysis),
            'clustered_items': sum(len(c['sample_urls']) for c in cluster_analysis.values()),
            'noise_items': len([l for l in cluster_labels if l == -1])
        }
    
    def discover_structural_clusters(self, metadata_list: List[Dict]) -> Dict[str, Any]:
        structure_patterns = defaultdict(list)
        
        for idx, metadata in enumerate(metadata_list):
            hierarchy = metadata.get('category_hierarchy', [])
            depth = metadata.get('depth_level', 0)
            
            structure_key = f"depth_{depth}_" + "_".join(hierarchy[:3])
            structure_patterns[structure_key].append(idx)
        
        structural_clusters = {}
        for pattern, indices in structure_patterns.items():
            if len(indices) >= self.min_cluster_size:
                sample_metadata = [metadata_list[i] for i in indices[:100]]
                common_terms = Counter()
                common_materials = Counter()
                
                for m in sample_metadata:
                    common_terms.update(m.get('extracted_terms', []))
                    for term in m.get('extracted_terms', []):
                        if term.lower() in ['brass', 'bronze', 'wood', 'glass', 'marble', 'walnut']:
                            common_materials[term.lower()] += 1
                
                structural_clusters[pattern] = {
                    'size': len(indices),
                    'pattern': pattern,
                    'common_terms': common_terms.most_common(15),
                    'common_materials': common_materials.most_common(10),
                    'sample_urls': [metadata_list[i]['full_url'] for i in indices[:5]]
                }
        
        return {
            'structural_clusters': structural_clusters,
            'total_patterns': len(structural_clusters),
            'largest_cluster': max(structural_clusters.values(), key=lambda x: x['size']) if structural_clusters else None
        }
    
    def discover_semantic_neighborhoods(self, metadata_list: List[Dict]) -> Dict[str, Any]:
        neighborhoods = defaultdict(set)
        term_associations = defaultdict(Counter)
        
        for metadata in metadata_list:
            terms = set(t.lower() for t in metadata.get('extracted_terms', []))
            
            for term in terms:
                term_associations[term].update(terms - {term})
        
        semantic_groups = {}
        processed_terms = set()
        
        for term, associations in term_associations.items():
            if term in processed_terms or sum(associations.values()) < 50:
                continue
            
            neighborhood = {term}
            related_terms = [t for t, c in associations.most_common(20) if c >= 10]
            
            for related in related_terms:
                if term_associations[related][term] >= 10:
                    neighborhood.add(related)
            
            if len(neighborhood) >= 3:
                group_name = "_".join(sorted(neighborhood)[:3])
                semantic_groups[group_name] = {
                    'core_terms': list(neighborhood),
                    'strength': sum(associations[t] for t in neighborhood),
                    'examples': self._find_examples_with_terms(neighborhood, metadata_list)[:5]
                }
                processed_terms.update(neighborhood)
        
        return {
            'semantic_neighborhoods': dict(sorted(
                semantic_groups.items(), 
                key=lambda x: x[1]['strength'], 
                reverse=True
            )[:50]),
            'total_neighborhoods': len(semantic_groups)
        }
    
    def discover_emergent_categories(self, metadata_list: List[Dict]) -> Dict[str, Any]:
        category_profiles = defaultdict(lambda: {
            'terms': Counter(),
            'materials': Counter(),
            'styles': Counter(),
            'origins': Counter(),
            'count': 0
        })
        
        material_keywords = {'wood', 'metal', 'glass', 'brass', 'bronze', 'walnut', 'marble'}
        style_keywords = {'vintage', 'antique', 'modern', 'contemporary', 'traditional'}
        origin_keywords = {'italian', 'french', 'danish', 'american', 'english'}
        
        for metadata in metadata_list:
            terms = [t.lower() for t in metadata.get('extracted_terms', [])]
            key_terms = []
            
            for term in terms:
                if term in material_keywords:
                    key_terms.append(f"material:{term}")
                elif term in style_keywords:
                    key_terms.append(f"style:{term}")
                elif term in origin_keywords:
                    key_terms.append(f"origin:{term}")
            
            if key_terms:
                category_key = "+".join(sorted(key_terms)[:3])
                profile = category_profiles[category_key]
                profile['terms'].update(terms)
                profile['count'] += 1
                
                for term in terms:
                    if term in material_keywords:
                        profile['materials'][term] += 1
                    elif term in style_keywords:
                        profile['styles'][term] += 1
                    elif term in origin_keywords:
                        profile['origins'][term] += 1
        
        emergent_categories = {}
        for category, profile in category_profiles.items():
            if profile['count'] >= 20:
                emergent_categories[category] = {
                    'count': profile['count'],
                    'top_terms': profile['terms'].most_common(15),
                    'materials': dict(profile['materials'].most_common()),
                    'styles': dict(profile['styles'].most_common()),
                    'origins': dict(profile['origins'].most_common())
                }
        
        return {
            'emergent_categories': dict(sorted(
                emergent_categories.items(),
                key=lambda x: x[1]['count'],
                reverse=True
            )[:30]),
            'total_categories': len(emergent_categories)
        }
    
    def _extract_cluster_characteristics(self, indices: List[int], metadata_list: List[Dict], 
                                       tfidf_matrix: np.ndarray, feature_names: List[str]) -> Dict:
        cluster_metadata = [metadata_list[i] for i in indices]
        
        terms_counter = Counter()
        categories_counter = Counter()
        materials_counter = Counter()
        styles_counter = Counter()
        
        material_keywords = {'wood', 'metal', 'glass', 'brass', 'bronze', 'walnut', 'marble'}
        style_keywords = {'vintage', 'antique', 'modern', 'contemporary', 'traditional'}
        
        for metadata in cluster_metadata:
            terms = metadata.get('extracted_terms', [])
            terms_counter.update(terms)
            
            hierarchy = metadata.get('category_hierarchy', [])
            if hierarchy:
                categories_counter.update(hierarchy)
            
            for term in terms:
                term_lower = term.lower()
                if term_lower in material_keywords:
                    materials_counter[term_lower] += 1
                elif term_lower in style_keywords:
                    styles_counter[term_lower] += 1
        
        cluster_tfidf = tfidf_matrix[indices].mean(axis=0).A1
        top_indices = cluster_tfidf.argsort()[-30:][::-1]
        top_terms = [(feature_names[i], cluster_tfidf[i]) for i in top_indices]
        
        return {
            'terms': top_terms,
            'categories': categories_counter.most_common(),
            'materials': materials_counter.most_common(),
            'styles': styles_counter.most_common()
        }
    
    def _find_examples_with_terms(self, terms: Set[str], metadata_list: List[Dict]) -> List[str]:
        examples = []
        for metadata in metadata_list:
            item_terms = set(t.lower() for t in metadata.get('extracted_terms', []))
            if terms.issubset(item_terms):
                examples.append(metadata['full_url'])
                if len(examples) >= 10:
                    break
        return examples
    
    def generate_clustering_report(self, metadata_list: List[Dict]) -> Dict[str, Any]:
        print("\nDiscovering content-based clusters...")
        content_clusters = self.discover_content_clusters(metadata_list[:5000])
        
        print("\nDiscovering structural clusters...")
        structural_clusters = self.discover_structural_clusters(metadata_list)
        
        print("\nDiscovering semantic neighborhoods...")
        semantic_neighborhoods = self.discover_semantic_neighborhoods(metadata_list)
        
        print("\nDiscovering emergent categories...")
        emergent_categories = self.discover_emergent_categories(metadata_list)
        
        return {
            'content_based_clustering': content_clusters,
            'structural_clustering': structural_clusters,
            'semantic_neighborhoods': semantic_neighborhoods,
            'emergent_categories': emergent_categories,
            'summary': {
                'total_content_clusters': content_clusters['total_clusters'],
                'total_structural_patterns': structural_clusters['total_patterns'],
                'total_semantic_neighborhoods': semantic_neighborhoods['total_neighborhoods'],
                'total_emergent_categories': emergent_categories['total_categories']
            }
        }