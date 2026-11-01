"""
AI & Heuristic Smart Document Parsing & Cross-Document Matching Engine
Unified Facade Coordinator for Egyptian Import Operations, Bills of Lading (B/L),
Commercial Invoices, Packing Lists, and Origin/Inspection Certificates.
"""

from modules.import_documentation.ai_parser_core import *
from modules.import_documentation.ai_bl_parser import *
from modules.import_documentation.ai_commercial_doc_parser import *
from modules.import_documentation.ai_certificate_parser import *
from modules.import_documentation.ai_reconciliation_matcher import *

# Dynamic __all__ export to preserve 100% backward compatibility for all imports
__all__ = [name for name in globals() if not name.startswith('__')]
