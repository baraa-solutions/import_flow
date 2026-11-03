"""
Smart Document Upload — Extractors Package
Each extractor handles field extraction for a specific module.
"""

from modules.smart_document_upload.extractors.base_extractor import BaseExtractor
from modules.smart_document_upload.extractors.nafeza_declaration_extractor import NafezaDeclarationExtractor
from modules.smart_document_upload.extractors.customs_clearance import CustomsClearanceExtractor

__all__ = [
    "BaseExtractor",
    "NafezaDeclarationExtractor",
    "CustomsClearanceExtractor",
]
