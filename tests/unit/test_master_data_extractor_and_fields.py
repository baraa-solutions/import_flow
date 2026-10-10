import pytest
from modules.smart_document_upload.extractors.master_data_entity import MasterDataEntityExtractor
from modules.suppliers.schemas import SupplierCreate, SupplierResponse
from modules.import_companies.schemas import ImportCompanyCreate, ImportCompanyResponse
from modules.external_service_providers.schemas import PartnerCreate


def test_master_data_entity_extractor_supplier_new_fields():
    extractor = MasterDataEntityExtractor()
    raw_text = """
    Supplier: Global Fabricators Ltd
    Supplier Registration Type: Commercial Register
    VAT No: CN987654321
    Country: China
    Address: 123 Industrial Zone, Shanghai
    Account No: 987654321012 SWIFTCode: BKCHCNBJ
    CargoX Platform Registered ID: 0x1234567890123456789012345678901234567890
    WIPO Madrid Monitor: 1234567
    ISO 9001: ISO-9001-2024
    """
    res = extractor.extract(raw_text, module_name="supplier")
    assert res["company_name"] == "Global Fabricators Ltd"
    assert res["account_number"] == "987654321012"
    assert res["swift_code"] == "BKCHCNBJ"
    assert res["cargox_id"] == "0x1234567890123456789012345678901234567890"
    assert res["has_wipo"] is True
    assert res["wipo_number"] == "1234567"
    assert res["has_iso_9001"] is True
    assert res["iso_9001_number"] == "ISO-9001-2024"
    assert extractor.compute_confidence(res) >= 0.8


def test_master_data_entity_extractor_importer_new_fields():
    extractor = MasterDataEntityExtractor()
    raw_text = """
    Company: El-Baraa Imports Co SAE
    Tax ID: 123-456-789
    CR: 45678
    Website: https://www.elbaraa.com
    Email: main@elbaraa.com
    Secondary Email: info2@elbaraa.com
    Mobile: 01012345678
    Fax: 02-23456789
    Nafeza Token: NFT-987654321
    EUIPO: 009876543
    Global Brand Database: GBD-112233
    Country: Egypt
    """
    res = extractor.extract(raw_text, module_name="import-company-entity")
    assert res["company_name"] == "El-Baraa Imports Co SAE"
    assert res["vat_tax_id"] == "123-456-789"
    assert res["commercial_register"] == "45678"
    assert res["website"] == "https://www.elbaraa.com"
    assert res["email"] == "main@elbaraa.com"
    assert res["secondary_email"] == "info2@elbaraa.com"
    assert res["mobile_number"] == "01012345678"
    assert res["fax_number"] == "02-23456789"
    assert res["nafeza_token"] == "NFT-987654321"
    assert res["has_euipo"] is True
    assert res["euipo_number"] == "009876543"
    assert res["has_global_brand"] is True
    assert res["global_brand_number"] == "GBD-112233"
    assert extractor.compute_confidence(res) >= 0.9


def test_schemas_supplier_trademark_fields():
    payload = {
        "company_name": "Acme Industrial Co",
        "country": "Germany",
        "has_wipo": True,
        "wipo_number": "WIPO-999",
        "has_euipo": True,
        "euipo_number": "EUIPO-888",
        "has_global_brand": False,
        "has_iso_9001": True,
        "iso_9001_number": "ISO-9001-2015-CERT",
    }
    obj = SupplierCreate(**payload)
    assert obj.has_wipo is True
    assert obj.wipo_number == "WIPO-999"
    assert obj.has_iso_9001 is True


def test_schemas_importer_contact_and_trademark_fields():
    payload = {
        "importer_name": "Nile Logistics Import SAE",
        "tax_id": "111-222-333",
        "website": "https://nile-import.eg",
        "secondary_email": "ops@nile-import.eg",
        "mobile": "+201012345678",
        "fax": "+20223456789",
        "nafeza_token": "SUPER_SECRET_TOKEN_123",
        "has_wipo": True,
        "wipo_number": "WIPO-111",
    }
    obj = ImportCompanyCreate(**payload)
    assert obj.website == "https://nile-import.eg"
    assert obj.secondary_email == "ops@nile-import.eg"
    assert obj.mobile == "+201012345678"
    assert obj.fax == "+20223456789"
    assert obj.nafeza_token == "SUPER_SECRET_TOKEN_123"
    assert obj.has_wipo is True


def test_schemas_partner_financial_fields():
    payload = {
        "partner_name": "Fast Freight Lines",
        "partner_type": "Freight Forwarder",
        "default_free_days": 14,
        "payment_terms": "Net 30 Days",
        "credit_limit": 50000.0,
    }
    obj = PartnerCreate(**payload)
    assert obj.default_free_days == 14
    assert obj.payment_terms == "Net 30 Days"
    assert obj.credit_limit == 50000.0


def test_crypto_utils_secret_token_encryption_and_masking():
    from utils.crypto_utils import encrypt_secret_text, decrypt_secret_text, mask_secret_token

    raw_token = "NFT-SECURE-9876543210"
    encrypted = encrypt_secret_text(raw_token)
    assert encrypted.startswith("enc:")
    assert encrypted != raw_token

    # Decrypt
    decrypted = decrypt_secret_text(encrypted)
    assert decrypted == raw_token

    # Masking
    masked = mask_secret_token(encrypted)
    assert masked == "****3210"

    # Already masked or empty
    assert mask_secret_token(None) is None
    assert mask_secret_token("") is None
    assert mask_secret_token("123") == "****"


def test_import_company_response_sanitizes_nafeza_token():
    from datetime import date, datetime, timezone
    from utils.crypto_utils import encrypt_secret_text

    raw_token = "NFT-TOP-SECRET-1234"
    enc_token = encrypt_secret_text(raw_token)

    data = {
        "company_id": 42,
        "importer_name": "Secure Trading LLC",
        "importer_id": "IMP-4200",
        "importer_id_expiry": date(2030, 1, 1),
        "vat_id": "VAT-4200",
        "vat_id_expiry": date(2030, 1, 1),
        "registration_number": "REG-4200",
        "registration_expiry": date(2030, 1, 1),
        "is_active": True,
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
        "nafeza_token": enc_token,
    }

    res = ImportCompanyResponse(**data)
    # The plaintext token must NEVER be returned
    assert res.nafeza_token is None
    # Presence flag must be True
    assert res.has_nafeza_token is True
    # Masked preview must display only last 4 characters
    assert res.masked_nafeza_token == "****1234"

