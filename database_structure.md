# Database Structure Documentation

## Overview
This is a **document-based/NoSQL structure** derived from 1stDibs marketplace URLs. The data is organized into multiple training datasets optimized for different machine learning tasks.

## Core Data Models

### 1. **Raw Metadata** (Source Structure)
**File**: `mini_metadata.json`
```json
{
  "full_url": "https://www.1stdibs.com/furniture/wall-decorations/decorative-art/poul-esting-tosca-color-lithograph-framed/id-f_34627762/",
  "domain": "www.1stdibs.com",
  "path_segments": ["furniture", "wall-decorations", "decorative-art", "poul-esting-tosca-color-lithograph-framed", "id-f_34627762"],
  "depth_level": 5,
  "item_id": "34627762", 
  "item_description": "poul-esting-tosca-color-lithograph-framed",
  "category_hierarchy": ["furniture", "wall-decorations", "decorative-art"],
  "extracted_terms": ["furniture", "wall", "decorations", "decorative", "art", "poul", "esting", "tosca", "color", "lithograph", "framed", "id", "f_34627762"],
  "numeric_values": ["34627762"],
  "hyphenated_terms": ["wall-decorations", "decorative-art", "poul-esting-tosca-color-lithograph-framed"],
  "capitalized_terms": []
}
```

**Schema**:
- `full_url` (string): Complete URL
- `domain` (string): Always "www.1stdibs.com"
- `path_segments` (array): URL path split by "/"
- `depth_level` (integer): Number of path segments (3-6)
- `item_id` (string): Extracted numeric ID
- `item_description` (string): Human-readable item name
- `category_hierarchy` (array): Categorical path
- `extracted_terms` (array): All words from URL
- `numeric_values` (array): Years, measurements, IDs
- `hyphenated_terms` (array): Multi-word concepts
- `capitalized_terms` (array): Proper nouns, brands

---

## Training Dataset Schemas

### 2. **Category Classification**
**Files**: `mini_category_classification_*.csv`

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `item_description` | string | Item name | "late-20th-century-georgian-style-three-pillar-mahogany-dining-table" |
| `all_terms` | string | Space-separated terms | "furniture tables dining room tables late 20th century..." |
| `primary_category` | string | Always "furniture" | "furniture" |
| `secondary_category` | string | Sub-category | "tables", "lighting", "seating" |

**Use Case**: Multi-class classification (22 classes)
**Records**: 1M total (70k train, 10k val, 20k test in mini)

### 3. **Era Classification** 
**Files**: `mini_era_classification_*.csv`

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `item_description` | string | Item name | "pair-of-vintage-washington-lamps-jean-michel-wilmotte-1980s" |
| `all_terms` | string | Space-separated terms | "furniture lighting table lamps pair of vintage..." |
| `primary_decade` | integer | Decade (1800-2020) | 1980, 1960, 1950 |

**Use Case**: Temporal classification
**Records**: 249k total (17k train, 2.5k val, 5k test in mini)

### 4. **Depth Prediction**
**Files**: `mini_depth_prediction_*.csv`

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `all_terms` | string | All extracted terms | "furniture tables coffee tables cocktail tables..." |
| `hyphenated_terms` | string | Multi-word concepts | "coffee-tables cocktail-tables low-table" |
| `depth_level` | integer | URL hierarchy depth (3-6) | 5, 6 |

**Use Case**: Regression/classification for URL structure prediction
**Records**: 1M total (70k train, 10k val, 20k test in mini)

### 5. **Text Embeddings**
**Files**: `mini_text_embeddings_*.csv`

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `text` | string | Various text representations | "ceramic-plate-pablo-picasso-1953" |
| `url` | string | Source URL | "https://www.1stdibs.com/..." |
| `primary_category` | string | Always "furniture" | "furniture" |
| `secondary_category` | string | Sub-category | "dining-entertaining" |
| `decade` | integer | Decade (0 if none) | 1950, 0 |

**Use Case**: Learning text embeddings, similarity search
**Records**: 2.9M total (199k train, 28k val, 57k test in mini)

### 6. **Sequence Data**
**Files**: `mini_sequence_data_*.csv`

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `sequence` | string | Input sequence | "furniture seating chairs italian-modern-metal-adjustable-chairs" |
| `target` | string | Next token to predict | "id-f_35043552" |
| `sequence_length` | integer | Length of input sequence | 4 |
| `url` | string | Source URL | "https://www.1stdibs.com/..." |

**Use Case**: Sequence-to-sequence models, URL generation
**Records**: 4.2M total (296k train, 42k val, 84k test in mini)

---

## Hierarchical Structure

### URL Path Hierarchy
```
furniture/                           # Level 0 (always "furniture")
├── lighting/                       # Level 1 (secondary category) 
│   ├── chandeliers-pendant-lights/ # Level 2 (tertiary category)
│   ├── table-lamps/
│   └── sconces-wall-lights/
├── seating/
│   ├── chairs/
│   ├── sofas/
│   └── benches/
├── tables/
│   ├── dining-room-tables/
│   ├── coffee-tables/
│   └── console-tables/
└── [item-description]/             # Level 3-4 (item name)
    └── id-f_[numeric_id]/         # Level 4-5 (item ID)
```

### Category Distribution (Top 10)
1. **lighting**: 16.9% (169k URLs)
2. **seating**: 13.5% (137k URLs)  
3. **decorative-objects**: 13.1% (133k URLs)
4. **rugs-carpets**: 12.4% (126k URLs)
5. **tables**: 11.7% (118k URLs)
6. **wall-decorations**: 6.6% (67k URLs)
7. **dining-entertaining**: 6.5% (66k URLs)
8. **storage-case-pieces**: 5.6% (57k URLs)
9. **more-furniture-collectibles**: 5.4% (55k URLs)
10. **building-garden**: 2.8% (28k URLs)

### Decade Distribution
1. **1960s**: 21.4% (53k records)
2. **1970s**: 18.5% (46k records)
3. **1950s**: 15.1% (38k records)
4. **1930s**: 6.3% (16k records)
5. **1980s**: 5.5% (14k records)

---

## Data Relationships

### Primary Keys
- **URL** (`full_url`): Unique identifier across all datasets
- **Item ID** (`item_id`): Numeric identifier from 1stDibs

### Foreign Key Relationships
```sql
-- If this were a relational database:
URLs (1) -> (M) Embeddings (via url)
URLs (1) -> (M) Sequences (via url)
Categories (1) -> (M) URLs (via secondary_category)
Decades (1) -> (M) URLs (via primary_decade)
```

### Data Joins
All datasets can be joined on `url` field to combine features:
- Join `category_classification` + `era_classification` for items with temporal data
- Join `text_embeddings` for rich text representations
- Join `sequence_data` for generative model features

---

## Storage Formats

### Available Formats
1. **CSV**: Human-readable, standard ML library support
2. **JSON Lines**: Streaming, flexible schema
3. **Parquet**: Columnar, compressed, fast analytics

### File Naming Convention
```
[mini_][dataset_name]_[split].[format]

Examples:
- mini_category_classification_train.csv
- era_classification_test.parquet 
- text_embeddings_validation.json
```

### Directory Structure
```
data/
├── training/           # Full dataset (10.4M records)
├── mini_training/      # 10% sample (1M records)
├── reports/
│   └── chunked/       # Processing intermediate files
└── raw/               # Original URL file
```

---

## Usage Patterns

### For Classification Models
```python
# Load category classification data
df = pd.read_csv('mini_category_classification_train.csv')
X = df['all_terms']  # Features
y = df['secondary_category']  # Labels (22 classes)
```

### For Sequence Models
```python  
# Load sequence data
df = pd.read_csv('mini_sequence_data_train.csv')
sequences = df['sequence']  # Input sequences
targets = df['target']      # Next tokens
```

### For Embedding Models
```python
# Load text embeddings data
df = pd.read_csv('mini_text_embeddings_train.csv')
texts = df['text']          # Various text representations
categories = df['secondary_category']  # Category labels
```

This structure supports both traditional ML approaches and modern deep learning pipelines for the 1stDibs marketplace dataset.