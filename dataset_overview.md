# Complete 1stDibs Dataset Overview

## 🚀 Project Summary

Successfully processed **1,012,070 URLs** from 1stDibs luxury marketplace and created comprehensive training datasets with HTML content sampling for model training.

## 📊 Dataset Components

### 1. **URL Metadata** (Complete - 1M URLs)
- **Source**: `data/raw/1m-urls-1stdibs-raw.txt`
- **Processed**: `data/reports/chunked/` (11 chunks, 100k each)
- **Structure**: URL parsing, category extraction, term analysis
- **Features**: 15+ metadata fields per URL

### 2. **Training Datasets** (ML-Ready)
**Full Dataset** (`data/training/`):
- **Category Classification**: 1M records (22 categories)
- **Era Classification**: 249k records (1880s-1990s)
- **Text Embeddings**: 2.9M text variations
- **Sequence Data**: 4.2M path sequences
- **Item Type Classification**: 1M fine-grained types

**Mini Dataset** (`data/mini_training/` - 10% sample):
- All datasets scaled to 101k base URLs
- **1M total training records**
- Same structure, 10x faster training

### 3. **HTML Content** (Sample)
**Downloaded** (`data/sample_html/`):
- **100 HTML pages** (100% success rate)
- **Parsed data** (`data/parsed_html/`)
- **Structured extraction**: titles, dimensions, materials, periods
- **29.2 images/product average**

## 🗄️ Database Structure

### Core Schema
```json
{
  "url": "https://www.1stdibs.com/furniture/lighting/table-lamps/...",
  "item_id": "34627762",
  "category_hierarchy": ["furniture", "lighting", "table-lamps"],
  "extracted_terms": ["vintage", "brass", "table", "lamp"],
  "depth_level": 5,
  "numeric_values": ["1960"],
  "materials": ["brass", "glass"],
  "title": "Vintage Brass Table Lamp",
  "dimensions": "Height: 24 in, Width: 12 in"
}
```

### Training Formats
- **CSV**: Standard ML library compatibility
- **JSON Lines**: Streaming/custom parsers
- **Parquet**: High-performance analytics

## 📈 Key Statistics

### Category Distribution
1. **Lighting**: 16.9% (169k URLs)
2. **Seating**: 13.5% (137k URLs)
3. **Decorative Objects**: 13.1% (133k URLs)
4. **Rugs & Carpets**: 12.4% (126k URLs)
5. **Tables**: 11.7% (118k URLs)

### Temporal Patterns
- **1960s**: Most frequent era (21.4% of dated items)
- **Mid-century modern** dominance (1950s-1970s)
- **249k items** with temporal data

### Content Quality
- **100% URL parsing** success rate
- **15.2 terms** average per URL
- **81.8%** follow 5-level hierarchy
- **Materials extracted**: wood, metal, glass, stone, textiles

## 🔧 Processing Pipeline

### 1. URL Processing (✅ Complete)
```bash
python process_chunks.py  # 38.4 seconds, 26,356 URLs/sec
```

### 2. Training Data Preparation (✅ Complete)
```bash
python prepare_training_data.py  # 18 datasets generated
```

### 3. Mini Dataset Creation (✅ Complete)
```bash
python create_mini_dataset.py  # 10% sample for development
```

### 4. HTML Download (✅ Sample Complete)
```bash
python download_html_sample.py  # 100 pages, 100% success
python download_html.py        # Full 101k download (ready to run)
```

### 5. HTML Parsing (✅ Sample Complete)
```bash
python parse_html_content.py   # Structured data extraction
```

## 🎯 Ready for Model Training

### Quick Start Examples

**Category Classification**:
```python
import pandas as pd
df = pd.read_csv('data/mini_training/mini_category_classification_train.csv')
X = df['all_terms']  # Text features
y = df['secondary_category']  # 22 categories
```

**Era Classification**:
```python
df = pd.read_csv('data/mini_training/mini_era_classification_train.csv')
X = df['item_description']
y = df['primary_decade']  # 1880-1990
```

**Text Embeddings**:
```python
df = pd.read_csv('data/mini_training/mini_text_embeddings_train.csv')
texts = df['text']  # Rich text representations
categories = df['secondary_category']
```

**Sequence Generation**:
```python
df = pd.read_csv('data/mini_training/mini_sequence_data_train.csv')
sequences = df['sequence']  # Input sequences
targets = df['target']     # Next tokens
```

## 📁 File Structure
```
battlefield/
├── data/
│   ├── raw/                    # Original 1M URLs
│   ├── reports/chunked/        # Processing metadata
│   ├── training/              # Full training datasets (10.4M records)
│   ├── mini_training/         # Mini datasets (1M records)
│   ├── sample_html/           # Downloaded HTML (100 files)
│   └── parsed_html/           # Structured HTML data
├── src/                       # Processing modules
│   ├── parsers/              # URL & HTML parsing
│   ├── analysis/             # Pattern discovery
│   └── clustering/           # Natural clustering
├── process_chunks.py          # Main URL processing
├── prepare_training_data.py   # ML dataset creation
├── create_mini_dataset.py     # 10% sampling
├── download_html.py          # HTML download (full)
├── download_html_sample.py   # HTML download (sample)
├── parse_html_content.py     # HTML → structured data
└── requirements.txt          # Dependencies
```

## 🎨 Use Cases

### Classification Models
- **Category prediction**: item description → furniture type
- **Era classification**: visual/text features → time period
- **Material identification**: description → material composition

### Generative Models
- **URL generation**: sequence model for marketplace URLs
- **Product description**: generate descriptions from categories
- **Style transfer**: transform descriptions between eras

### Embedding Models
- **Semantic search**: find similar furniture items
- **Cross-modal**: link text descriptions to visual features
- **Recommendation**: suggest similar products

### Content Analysis
- **Price prediction**: features → market value
- **Trend analysis**: temporal pattern discovery
- **Market segmentation**: natural clustering

## 🚀 Next Steps

### Immediate (Ready to Use)
1. **Train models** on mini dataset (1M records)
2. **Validate approaches** with 10% data
3. **Optimize hyperparameters** quickly

### Scale Up
1. **Full dataset training** (10.4M records)
2. **Complete HTML download** (101k pages)
3. **Enhanced feature engineering**

### Advanced
1. **Image scraping** from HTML
2. **Price prediction** modeling
3. **Visual-text alignment**

## 💾 Data Access

**Load any dataset**:
```python
import pandas as pd

# Mini dataset (fast)
df = pd.read_csv('data/mini_training/mini_[dataset]_[split].csv')

# Full dataset (complete)
df = pd.read_csv('data/training/[dataset]_[split].csv')

# Parsed HTML
df = pd.read_csv('data/parsed_html/parsed_products.csv')
```

**All datasets include**:
- Pre-split train/validation/test (70/10/20%)
- Multiple formats (CSV, JSON, Parquet)
- Comprehensive metadata and documentation

This dataset is now ready for machine learning model training across multiple tasks and modalities!