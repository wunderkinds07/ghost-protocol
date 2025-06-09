# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a data analysis project focused on discovering patterns and extracting metadata from a large dataset of 1stDibs URLs. The project aims to perform open pattern discovery without imposing predefined taxonomies, letting natural structures emerge from the data.

## Dataset

- **Primary data file**: `1m-urls-1stdibs-raw.txt` - Contains approximately 1 million URLs from 1stDibs marketplace
- **URL structure**: `https://www.1stdibs.com/furniture/{category}/{subcategory}/{item-description}/id-{id}/`
- URLs contain rich metadata about furniture, decorative objects, art pieces, and other luxury items

## Development Approach

### Pattern Discovery Methodology
When analyzing this dataset, follow the principles outlined in `tst.txt`:
1. **Extract everything** - Capture all metadata without filtering
2. **Discover patterns** - Find natural groupings and relationships
3. **Emerge taxonomies** - Let classification systems arise from data patterns
4. **Evidence-based** - Support every insight with quantitative evidence

### Key Analysis Areas
- URL path structure analysis (depth, segments, hierarchies)
- Item description extraction (materials, styles, periods, origins)
- Frequency analysis (common terms, co-occurrences)
- Natural clustering (emergent categories)

## Common Development Tasks

### Data Processing Setup
```bash
# Create Python virtual environment
python -m venv venv
source venv/bin/activate  # macOS/Linux

# Install typical dependencies for data analysis
pip install pandas numpy requests beautifulsoup4
pip install matplotlib seaborn jupyter
```

### URL Analysis Tools
When implementing URL parsing:
- Use `urllib.parse` for URL component extraction
- Extract all path segments without interpretation
- Capture numeric IDs from URL patterns
- Preserve original URL structure for pattern analysis

### Pattern Mining Implementation
- Use frequency counting for all unique elements
- Implement co-occurrence analysis for term relationships
- Build hierarchical pattern detection from URL structures
- Create clustering algorithms that don't impose categories

## Architecture Considerations

### Data Flow
1. **Raw URLs** → Parse and extract all metadata
2. **Metadata** → Pattern discovery and frequency analysis
3. **Patterns** → Natural clustering and taxonomy emergence
4. **Insights** → Quantified findings with evidence

### Output Formats
Generate outputs as JSON for:
- Complete metadata inventory
- Structural pattern analysis
- Natural clustering results
- Emergent insights with statistical support

## Implementation Notes

- Process URLs in batches to handle the 1M dataset efficiently
- Store intermediate results to avoid reprocessing
- Use parallel processing where possible for URL parsing
- Maintain evidence trail for all discovered patterns