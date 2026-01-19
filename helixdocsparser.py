#!/usr/bin/env python3
"""
Helix Documentation to PDF Converter (Fixed)
==============================================
Scrapes the entire Helix documentation site and converts it to a single formatted PDF.

Requirements:
    pip install requests beautifulsoup4 weasyprint --break-system-packages

Usage:
    python3 helixdocsparser.py
"""

import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse, urldefrag
import time
import re
from pathlib import Path
from datetime import datetime

try:
    from weasyprint import HTML, CSS
    PDF_ENGINE = "weasyprint"
except ImportError:
    PDF_ENGINE = None

BASE_URL = "https://docs.gethelix.co/"
OUTPUT_FILE = "helix_documentation.pdf"
REQUEST_DELAY = 0.1


def get_soup(url: str) -> BeautifulSoup:
    """Fetch a page and return BeautifulSoup object."""
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }
    response = requests.get(url, headers=headers, timeout=30)
    response.raise_for_status()
    return BeautifulSoup(response.text, "html.parser")


def extract_all_page_urls(base_url: str) -> list[dict]:
    """Extract all UNIQUE documentation page URLs (no anchor duplicates)."""
    soup = get_soup(base_url)
    pages = []
    seen_base_urls = set()
    
    for link in soup.find_all("a", href=True):
        href = link["href"]
        full_url = urljoin(base_url, href)
        
        # Remove the fragment/anchor to get base URL
        base_url_clean, fragment = urldefrag(full_url)
        
        # Skip if not internal or already seen
        if not base_url_clean.startswith(base_url):
            continue
        if base_url_clean in seen_base_urls:
            continue
        
        parsed = urlparse(base_url_clean)
        if parsed.netloc and parsed.netloc != urlparse(base_url).netloc:
            continue
        
        seen_base_urls.add(base_url_clean)
        
        # Determine section from URL path
        path = parsed.path.strip("/")
        if path:
            parts = path.split("/")
            section = parts[0].upper()
            # Use the last part of path as a better title hint
            title_hint = parts[-1] if parts[-1] else parts[-2] if len(parts) > 1 else path
        else:
            section = "MAIN"
            title_hint = "Introduction"
        
        pages.append({
            "url": base_url_clean,
            "title_hint": title_hint,
            "section": section
        })
    
    return pages


def extract_page_content(url: str, title_hint: str) -> dict:
    """Extract the main content from a documentation page."""
    soup = get_soup(url)
    
    # Try to find the main content area
    content = None
    for selector in ["article", "main", ".content", ".documentation", "#content"]:
        if selector.startswith(".") or selector.startswith("#"):
            content = soup.select_one(selector)
        else:
            content = soup.find(selector)
        if content:
            break
    
    if not content:
        content = soup.body or soup
    
    # Get a GOOD title - prefer the first h1 inside content, or use path-based hint
    title = ""
    
    # Look for first h1 in the content
    h1 = content.find("h1") if content else soup.find("h1")
    if h1:
        title = h1.get_text(strip=True)
    
    # If title is generic or empty, use the title hint from URL
    if not title or title.lower() in ["helix documentation", "documentation", ""]:
        # Convert URL path segment to readable title
        title = title_hint.replace("-", " ").replace("_", " ").title()
        # Handle special cases like "ix.char" -> "ix.char"
        if "." in title_hint:
            title = title_hint
    
    # Clean up the content - remove nav elements
    for elem in content.find_all(["nav", "aside", "footer", "script", "style"]):
        elem.decompose()
    
    for class_pattern in ["sidebar", "navigation", "nav-", "menu", "footer", "header", "toc"]:
        for elem in content.find_all(class_=re.compile(class_pattern, re.I)):
            elem.decompose()
        for elem in content.find_all(id=re.compile(class_pattern, re.I)):
            elem.decompose()
    
    return {
        "title": title,
        "html": str(content),
        "url": url
    }


def create_combined_html(pages_content: list[dict], sections_order: list[str]) -> str:
    """Create a single HTML document from all pages."""
    
    # Group pages by section
    sections = {}
    for page in pages_content:
        section = page.get("section", "OTHER")
        if section not in sections:
            sections[section] = []
        sections[section].append(page)
    
    html_parts = ["""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Helix Documentation</title>
    <style>
        @page {
            size: A4;
            margin: 1.5cm;
            @bottom-center {
                content: counter(page);
            }
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            line-height: 1.5;
            color: #333;
            font-size: 10pt;
        }
        
        .cover {
            page-break-after: always;
            text-align: center;
            padding-top: 35%;
        }
        
        .cover h1 {
            font-size: 2.5em;
            color: #7B68EE;
        }
        
        .cover .subtitle {
            font-size: 1.3em;
            color: #666;
        }
        
        .cover .date {
            margin-top: 2em;
            color: #999;
        }
        
        .toc {
            page-break-after: always;
        }
        
        .toc h2 {
            color: #7B68EE;
            border-bottom: 2px solid #7B68EE;
        }
        
        .toc ul {
            list-style: none;
            padding-left: 0;
            column-count: 2;
            column-gap: 2em;
        }
        
        .toc li {
            margin: 0.2em 0;
            font-size: 9pt;
            break-inside: avoid;
        }
        
        .toc .section-title {
            font-weight: bold;
            font-size: 1.1em;
            margin-top: 1em;
            color: #7B68EE;
            column-span: all;
        }
        
        .section-header {
            page-break-before: always;
            background: #7B68EE;
            color: white;
            padding: 1.5em;
            margin: -1.5cm -1.5cm 1em -1.5cm;
            text-align: center;
        }
        
        .section-header h2 {
            margin: 0;
            font-size: 2em;
        }
        
        .page-content {
            page-break-before: always;
            margin-bottom: 1em;
        }
        
        .page-content:first-of-type {
            page-break-before: avoid;
        }
        
        .page-title {
            color: #7B68EE;
            border-bottom: 1px solid #ddd;
            padding-bottom: 0.3em;
            margin-bottom: 0.5em;
            font-size: 1.4em;
        }
        
        .page-url {
            font-size: 0.7em;
            color: #999;
            margin-bottom: 0.8em;
        }
        
        code, pre {
            font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
            background: #f6f8fa;
            border-radius: 3px;
            font-size: 0.85em;
        }
        
        code {
            padding: 0.15em 0.3em;
        }
        
        pre {
            padding: 0.8em;
            overflow-x: auto;
            border: 1px solid #e1e4e8;
            white-space: pre-wrap;
            word-wrap: break-word;
        }
        
        pre code {
            padding: 0;
            background: none;
        }
        
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 0.8em 0;
            font-size: 0.9em;
        }
        
        th, td {
            border: 1px solid #ddd;
            padding: 0.4em;
            text-align: left;
        }
        
        th {
            background: #f6f8fa;
        }
        
        h1, h2, h3, h4, h5, h6 {
            color: #24292e;
            margin-top: 1.2em;
            margin-bottom: 0.4em;
        }
        
        h1 { font-size: 1.6em; }
        h2 { font-size: 1.3em; }
        h3 { font-size: 1.1em; }
        
        a {
            color: #7B68EE;
            text-decoration: none;
        }
        
        ul, ol {
            padding-left: 1.5em;
            margin: 0.5em 0;
        }
        
        li {
            margin: 0.2em 0;
        }
        
        blockquote {
            border-left: 3px solid #7B68EE;
            margin: 0.8em 0;
            padding: 0.3em 0.8em;
            background: #f9f9f9;
        }
        
        img {
            max-width: 100%;
            height: auto;
        }
    </style>
</head>
<body>
"""]
    
    # Cover page
    html_parts.append(f"""
    <div class="cover">
        <h1>Helix Documentation</h1>
        <p class="subtitle">The Better Gamemode Framework</p>
        <p class="date">Generated on {datetime.now().strftime('%B %d, %Y')}</p>
        <p class="date">Source: docs.gethelix.co</p>
    </div>
""")
    
    # Table of Contents
    html_parts.append("""
    <div class="toc">
        <h2>Table of Contents</h2>
""")
    
    for section in sections_order:
        if section in sections and sections[section]:
            html_parts.append(f'        <p class="section-title">{section.title()}</p>\n        <ul>\n')
            for page in sections[section]:
                title = page.get("title", "Untitled")
                html_parts.append(f'            <li>{title}</li>\n')
            html_parts.append('        </ul>\n')
    
    # Add any sections not in the predefined order
    for section in sections:
        if section not in sections_order and sections[section]:
            html_parts.append(f'        <p class="section-title">{section.title()}</p>\n        <ul>\n')
            for page in sections[section]:
                title = page.get("title", "Untitled")
                html_parts.append(f'            <li>{title}</li>\n')
            html_parts.append('        </ul>\n')
    
    html_parts.append("    </div>\n")
    
    # Content pages by section
    all_sections = sections_order + [s for s in sections if s not in sections_order]
    
    for section in all_sections:
        if section not in sections or not sections[section]:
            continue
        
        html_parts.append(f"""
    <div class="section-header">
        <h2>{section.title()}</h2>
    </div>
""")
        
        for i, page in enumerate(sections[section]):
            page_class = "page-content" + (" first-in-section" if i == 0 else "")
            html_parts.append(f"""
    <div class="{page_class}">
        <h3 class="page-title">{page.get('title', 'Untitled')}</h3>
        <p class="page-url">{page.get('url', '')}</p>
        {page.get('html', '')}
    </div>
""")
    
    html_parts.append("""
</body>
</html>
""")
    
    return "".join(html_parts)


def main():
    print("=" * 60)
    print("Helix Documentation to PDF Converter (Fixed)")
    print("=" * 60)
    
    if PDF_ENGINE is None:
        print("\nERROR: WeasyPrint not available!")
        print("Install with: pip install weasyprint --break-system-packages")
        return
    
    print(f"\nUsing PDF engine: {PDF_ENGINE}")
    
    # Step 1: Get all UNIQUE page URLs (no anchor duplicates)
    print("\n[1/4] Discovering documentation pages...")
    pages_info = extract_all_page_urls(BASE_URL)
    print(f"      Found {len(pages_info)} unique pages (duplicates removed)")
    
    sections_order = ["MAIN", "MANUAL", "HOOKS", "LIBRARIES", "CLASSES", "PANELS"]
    
    # Step 2: Scrape each page
    print("\n[2/4] Scraping page content...")
    pages_content = []
    
    for i, page_info in enumerate(pages_info):
        url = page_info["url"]
        print(f"      [{i+1}/{len(pages_info)}] {page_info['title_hint'][:40]}...")
        
        try:
            content = extract_page_content(url, page_info["title_hint"])
            content["section"] = page_info["section"]
            pages_content.append(content)
        except Exception as e:
            print(f"      WARNING: Failed to scrape {url}: {e}")
        
        time.sleep(REQUEST_DELAY)
    
    print(f"      Successfully scraped {len(pages_content)} pages")
    
    # Step 3: Combine into HTML
    print("\n[3/4] Generating combined HTML document...")
    combined_html = create_combined_html(pages_content, sections_order)
    
    html_output = OUTPUT_FILE.replace('.pdf', '.html')
    with open(html_output, 'w', encoding='utf-8') as f:
        f.write(combined_html)
    print(f"      Saved HTML: {html_output}")
    
    # Step 4: Convert to PDF
    print(f"\n[4/4] Converting to PDF (this may take a few minutes)...")
    try:
        HTML(string=combined_html).write_pdf(OUTPUT_FILE)
        
        print(f"      Saved PDF: {OUTPUT_FILE}")
        
        file_size = Path(OUTPUT_FILE).stat().st_size
        if file_size > 1024 * 1024:
            size_str = f"{file_size / (1024 * 1024):.2f} MB"
        else:
            size_str = f"{file_size / 1024:.2f} KB"
        print(f"      File size: {size_str}")
        
    except Exception as e:
        print(f"      ERROR generating PDF: {e}")
        print(f"      HTML file saved - open in Chrome and Print to PDF as backup")
    
    print("\n" + "=" * 60)
    print("Done!")
    print("=" * 60)


if __name__ == "__main__":
    main()