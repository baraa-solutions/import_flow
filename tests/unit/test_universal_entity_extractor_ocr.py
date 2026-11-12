"""
Universal Entity Extractor — image / PDF OCR pipeline & field parsing accuracy (Trello v9QVwJlh).

Fixtures are synthetic and generated in-test (PIL images, PyMuPDF PDFs): a text-layer PDF, a scanned
(image-only) PDF, a mixed PDF and PNG / JPEG scans. The OCR engine is injected as a fake runner so the
routing is tested without RapidOCR / Tesseract installed; the "no engine installed" path is tested explicitly.
"""

from __future__ import annotations

import io
from types import SimpleNamespace
from unittest.mock import MagicMock

import fitz
import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from PIL import Image, ImageDraw

import modules.smart_document_upload.ocr_pipeline as pipeline
import modules.smart_document_upload.service as sdu_service
from modules.smart_document_upload.extractors.master_data_entity import (
    MasterDataEntityExtractor,
    compact_iban_candidate,
    iban_checksum_valid,
)
from modules.smart_document_upload.ocr_pipeline import (
    KIND_IMAGE,
    KIND_OFFICE,
    KIND_PDF,
    KIND_TEXT,
    MAX_OCR_PDF_PAGES,
    OcrUnavailableError,
    detect_document_kind,
    extract_document_text,
    normalize_extracted_text,
    preprocess_image_for_ocr,
)


# ─── Synthetic fixtures ───────────────────────────────────────────────────────

SUPPLIER_CARD_TEXT = (
    "Company Name: Nile Delta Trading Co. S.A.E\n"
    "CargoX Platform Registered ID No.: CX-EG-2024-00731\n"
    "Phone: +20 2 2345 6789\n"
    "Email: info@niledelta.com"
)


def make_iban(country: str, bban: str) -> str:
    """Builds a checksum-valid IBAN for the synthetic documents."""
    rearranged = bban + country + "00"
    digits = "".join(str(int(ch, 36)) for ch in rearranged)
    check = 98 - int(digits) % 97
    return f"{country}{check:02d}{bban}"


EG_IBAN = make_iban("EG", "0019000500000000263180002")
DE_IBAN = make_iban("DE", "370400440532013000")


def make_png(text: str = "ACME TRADING CO", size=(400, 120), fmt: str = "PNG") -> bytes:
    img = Image.new("RGB", size, "white")
    ImageDraw.Draw(img).text((10, 40), text, fill="black")
    buf = io.BytesIO()
    img.save(buf, format=fmt)
    return buf.getvalue()


def make_text_pdf(pages) -> bytes:
    doc = fitz.open()
    for page_text in pages:
        page = doc.new_page()
        page.insert_text((72, 72), page_text, fontsize=11)
    data = doc.tobytes()
    doc.close()
    return data


def make_scanned_pdf(page_count: int = 1) -> bytes:
    doc = fitz.open()
    png = make_png()
    for _ in range(page_count):
        page = doc.new_page()
        page.insert_image(fitz.Rect(50, 50, 450, 170), stream=png)
    data = doc.tobytes()
    doc.close()
    return data


def make_mixed_pdf() -> bytes:
    doc = fitz.open()
    doc.new_page().insert_text((72, 72), SUPPLIER_CARD_TEXT, fontsize=11)
    doc.new_page().insert_image(fitz.Rect(50, 50, 450, 170), stream=make_png())
    data = doc.tobytes()
    doc.close()
    return data


class FakeOcr:
    """Injectable OCR runner: records the images it received and returns canned text."""

    def __init__(self, text: str = SUPPLIER_CARD_TEXT, engine: str = "fake-ocr"):
        self.text = text
        self.engine = engine
        self.images = []

    def __call__(self, image):
        self.images.append(image)
        return self.text, self.engine


def no_ocr_engine(_image):
    raise OcrUnavailableError(pipeline.OCR_UNAVAILABLE_MESSAGE)


# ─── Text normalization ───────────────────────────────────────────────────────

def test_normalize_converts_eastern_arabic_and_persian_digits():
    assert normalize_extracted_text("رقم السجل: ١٢٣٤٥٦ / ۷۸۹") == "رقم السجل: 123456 / 789"


def test_normalize_arabic_separators_and_invisible_marks():
    raw = "‏المبلغ: ١٬٢٥٠٫٥٠‎‫\nشـــركة"
    assert normalize_extracted_text(raw) == "المبلغ: 1,250.50\nشركة"


def test_normalize_folds_arabic_presentation_forms_from_pdf_text_layers():
    # "شركة" written with Arabic presentation-form glyphs, as some PDF generators emit it
    presentation = "ﺷﺮﻛﺓ"
    assert normalize_extracted_text(presentation) == "شركة"


def test_normalize_collapses_spaces_and_crlf():
    assert normalize_extracted_text("  A  B  \r\n\r\n\r\n\r\nC ") == "A B\n\nC"


# ─── File-type routing ────────────────────────────────────────────────────────

@pytest.mark.parametrize(
    "filename, payload, expected",
    [
        ("card.pdf", b"%PDF-1.7 ...", KIND_PDF),
        ("card.png", b"\x89PNG\r\n\x1a\n....", KIND_IMAGE),
        ("card.jpg", b"\xff\xd8\xff\xe0....", KIND_IMAGE),
        ("card.webp", b"RIFF\x00\x00\x00\x00WEBPVP8 ", KIND_IMAGE),
        ("card.tiff", b"II*\x00....", KIND_IMAGE),
        ("card.docx", b"PK\x03\x04....", KIND_OFFICE),
        ("card.txt", b"Company: Acme", KIND_TEXT),
        # Content wins over a wrong extension (renamed scans)
        ("scan.pdf", b"\x89PNG\r\n\x1a\n....", KIND_IMAGE),
        ("profile.txt", b"%PDF-1.4 ...", KIND_PDF),
    ],
)
def test_detect_document_kind(filename, payload, expected):
    assert detect_document_kind(filename, payload) == expected


def test_text_layer_pdf_never_calls_ocr():
    ocr = FakeOcr()
    result = extract_document_text("profile.pdf", make_text_pdf([SUPPLIER_CARD_TEXT]), ocr_runner=ocr)
    assert result.method == "text_layer"
    assert result.ocr_pages == 0 and ocr.images == []
    assert "CX-EG-2024-00731" in result.text
    assert result.pages_total == 1


def test_scanned_pdf_is_rasterized_and_ocred():
    ocr = FakeOcr()
    result = extract_document_text("scan.pdf", make_scanned_pdf(1), ocr_runner=ocr)
    assert result.kind == KIND_PDF
    assert result.method == "ocr"
    assert result.ocr_pages == 1 and result.ocr_engine == "fake-ocr"
    assert len(ocr.images) == 1
    assert ocr.images[0].mode == "L"  # pre-processed (grayscale) before OCR
    assert "Nile Delta Trading" in result.text


def test_scanned_pdf_ocr_is_capped_to_first_pages():
    ocr = FakeOcr()
    result = extract_document_text("scan.pdf", make_scanned_pdf(5), ocr_runner=ocr)
    assert result.pages_total == 5
    assert result.ocr_pages == MAX_OCR_PDF_PAGES == 3
    assert len(ocr.images) == 3


def test_mixed_pdf_uses_text_layer_and_ocr():
    ocr = FakeOcr(text="WIPO Registration No.: 1587432")
    result = extract_document_text("mixed.pdf", make_mixed_pdf(), ocr_runner=ocr)
    assert result.method == "mixed"
    assert result.ocr_pages == 1
    assert "CX-EG-2024-00731" in result.text and "1587432" in result.text


@pytest.mark.parametrize("fmt, name", [("PNG", "card.png"), ("JPEG", "card.jpg")])
def test_image_upload_is_preprocessed_and_ocred(fmt, name):
    ocr = FakeOcr()
    result = extract_document_text(name, make_png(fmt=fmt), ocr_runner=ocr)
    assert result.kind == KIND_IMAGE and result.method == "ocr"
    image = ocr.images[0]
    assert image.mode == "L"
    assert max(image.size) >= 1000  # 400 px wide scan was upscaled for OCR
    assert "Nile Delta Trading" in result.text


def test_preprocess_flattens_transparency_and_bounds_size():
    rgba = Image.new("RGBA", (5000, 100), (0, 0, 0, 0))
    out = preprocess_image_for_ocr(rgba)
    assert out.mode == "L"
    assert max(out.size) <= pipeline.MAX_OCR_LONG_EDGE_PX


def test_ocr_text_with_eastern_digits_is_normalized():
    ocr = FakeOcr(text="السجل التجاري: ٢٢٨٧٩٥\nCargoX ID: ٠x" + "a" * 40)
    result = extract_document_text("card.png", make_png(), ocr_runner=ocr)
    assert "228795" in result.text


def test_unreadable_image_reports_warning_not_crash():
    result = extract_document_text("broken.png", b"\x89PNG\r\n\x1a\nnot-really", ocr_runner=FakeOcr())
    assert not result.has_text
    assert any(w.startswith("image_unreadable") for w in result.warnings)


def test_plain_text_file_routed_without_ocr():
    ocr = FakeOcr()
    result = extract_document_text("card.txt", SUPPLIER_CARD_TEXT.encode("utf-8"), ocr_runner=ocr)
    assert result.method == "plain" and ocr.images == []
    assert "Nile Delta" in result.text


# ─── OCR engine unavailable ───────────────────────────────────────────────────

def test_image_without_ocr_engine_flags_unavailable():
    result = extract_document_text("card.png", make_png(), ocr_runner=no_ocr_engine)
    assert result.ocr_required and result.ocr_unavailable
    assert not result.has_text


def test_scanned_pdf_without_ocr_engine_flags_unavailable():
    result = extract_document_text("scan.pdf", make_scanned_pdf(2), ocr_runner=no_ocr_engine)
    assert result.ocr_unavailable and not result.has_text


def test_run_ocr_raises_when_no_engine_installed(monkeypatch):
    monkeypatch.setattr(pipeline, "_rapidocr_engine", lambda: None)
    monkeypatch.setattr(pipeline, "find_tesseract_binary", lambda: None)
    assert pipeline.available_ocr_engines() == []
    with pytest.raises(OcrUnavailableError):
        pipeline.run_ocr_on_image(Image.new("L", (10, 10), 255))


def test_run_ocr_uses_tesseract_cli_when_only_binary_present(monkeypatch):
    monkeypatch.setattr(pipeline, "_rapidocr_engine", lambda: None)
    monkeypatch.setattr(pipeline, "find_tesseract_binary", lambda: "/usr/bin/tesseract")
    monkeypatch.setattr(pipeline, "_pytesseract_installed", lambda: False)
    calls = []

    def fake_run(cmd, **kwargs):
        calls.append(cmd)
        if "--list-langs" in cmd:
            return SimpleNamespace(returncode=0, stdout=b"List of languages:\nara\neng\n", stderr=b"")
        return SimpleNamespace(returncode=0, stdout=SUPPLIER_CARD_TEXT.encode(), stderr=b"")

    monkeypatch.setattr(pipeline.subprocess, "run", fake_run)
    text, engine = pipeline.run_ocr_on_image(Image.new("L", (100, 100), 255))
    assert engine == "tesseract-cli"
    assert "Nile Delta" in text
    assert any("ara+eng" in cmd for cmd in calls)


def test_service_raises_clear_422_when_ocr_missing(monkeypatch):
    monkeypatch.setattr(pipeline, "run_ocr_on_image", no_ocr_engine)
    with pytest.raises(HTTPException) as exc:
        sdu_service.extract_entity_document_text("card.png", make_png())
    assert exc.value.status_code == 422
    assert "OCR" in exc.value.detail


def test_service_raises_422_when_scan_has_no_text(monkeypatch):
    monkeypatch.setattr(pipeline, "run_ocr_on_image", lambda image: ("", "fake-ocr"))
    with pytest.raises(HTTPException) as exc:
        sdu_service.extract_entity_document_text("blank.png", make_png(text=""))
    assert exc.value.status_code == 422
    assert "No readable text" in exc.value.detail


def _fallback_db():
    db = MagicMock()
    db.query.side_effect = RuntimeError("no database in this unit test")
    return db


def test_parse_uploaded_png_extracts_entity_fields(monkeypatch):
    ocr_text = (
        "شركة النيل للتجارة والاستيراد ش.م.م\n"
        "Company Name: Nile Delta Trading Co. S.A.E\n"
        "السجل التجاري: ٢٢٨٧٩٥\n"
        "CargoX Platform Registered ID No.: CX-EG-2024-00731\n"
        f"IBAN: {EG_IBAN[:4]} {EG_IBAN[4:8]} {EG_IBAN[8:12]} {EG_IBAN[12:]}\n"
        "SWIFT Code: NBEGEGCX001\n"
        "Account No.: 1903 0005 0000 263\n"
        "Country: Egypt"
    )
    monkeypatch.setattr(pipeline, "run_ocr_on_image", FakeOcr(text=ocr_text))
    result = sdu_service.parse_uploaded_document(
        db=_fallback_db(),
        module_name="import-company-entity",
        filename="registration_card.png",
        file_type="image",
        content_bytes=make_png(),
        save_session=False,
    )
    fields = result["extracted_fields"]
    assert fields["company_name"] == "Nile Delta Trading Co. S.A.E"
    assert fields["commercial_register"] == "228795"
    assert fields["cargox_id"] == "CX-EG-2024-00731"
    assert fields["iban"] == EG_IBAN
    assert fields["swift_code"] == "NBEGEGCX001"
    assert fields["account_number"] == "1903 0005 0000 263"
    assert result["document_text_info"]["method"] == "ocr"
    assert result["document_text_info"]["ocr_engine"] == "fake-ocr"
    for key in ("company_name", "cargox_id", "iban", "swift_code", "account_number"):
        assert key in result["fields_found"]
    assert result["confidence_score"] >= 0.8


def test_parse_uploaded_document_for_non_entity_module_keeps_legacy_path(monkeypatch):
    called = {}

    def legacy(filename, content_bytes):
        called["legacy"] = True
        return "Invoice No: 1", {}

    monkeypatch.setattr(sdu_service, "extract_raw_text_and_boxes", legacy)
    result = sdu_service.parse_uploaded_document(
        db=_fallback_db(), module_name="coo-certificate", filename="coo.txt",
        file_type="text", content_bytes=b"Invoice No: 1", save_session=False,
    )
    assert called.get("legacy") is True
    assert result["fields_found"] is None and result["document_text_info"] is None


def test_upload_endpoint_returns_422_with_message_when_ocr_missing(monkeypatch):
    from database.database import get_db
    from modules.auth.router import get_current_user
    from modules.smart_document_upload.router import router

    monkeypatch.setattr(pipeline, "run_ocr_on_image", no_ocr_engine)
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(is_admin=True, user_id=1)
    app.dependency_overrides[get_db] = _fallback_db
    client = TestClient(app)

    resp = client.post(
        "/api/v1/smart-upload/upload/supplier-entity",
        files={"file": ("card.png", make_png(), "image/png")},
        data={"save_session": "false"},
    )
    assert resp.status_code == 422
    assert "OCR" in resp.json()["detail"]


# ─── Field parsing accuracy ───────────────────────────────────────────────────

@pytest.fixture
def extractor():
    return MasterDataEntityExtractor()


@pytest.mark.parametrize(
    "line, expected",
    [
        ("CargoX Platform Registered ID No.: CX-EG-2024-00731", "CX-EG-2024-00731"),
        ("CargoX Platform Registered ID: 0x1234567890123456789012345678901234567890",
         "0x1234567890123456789012345678901234567890"),
        ("CARGOX ID # EG_SOROUR_01", "EG_SOROUR_01"),
        ("Cargo-X Company Account No. 4471 2290", "4471 2290"),
        ("Cargo X Wallet Address - CRGX-55120", "CRGX-55120"),
        ("معرف كارجو إكس: ٧٧٨٨١٢", "778812"),
        ("رقم التسجيل على منصة كارجو اكس: CX-778812", "CX-778812"),
        ("Registered on CX-ABC12345 network", "CX-ABC12345"),
    ],
)
def test_cargox_id_formats(extractor, line, expected):
    assert extractor.extract(f"ACME Trading Ltd\n{line}")["cargox_id"] == expected


def test_cargox_label_without_value_is_not_a_word(extractor):
    res = extractor.extract("ACME Trading Ltd\nCargoX Platform Registered ID: Registered\nCountry: Italy")
    assert res["cargox_id"] is None


def test_iban_swift_and_account_are_never_mixed(extractor):
    text = (
        "Beneficiary: ACME Trading Ltd\n"
        "Bank Name: Commerzbank AG\n"
        "Account No: 0532013000 SWIFT/BIC: COBADEFFXXX\n"
        f"IBAN: {DE_IBAN[:4]} {DE_IBAN[4:8]} {DE_IBAN[8:12]} {DE_IBAN[12:16]} {DE_IBAN[16:20]} {DE_IBAN[20:]} SWIFT: COBADEFFXXX"
    )
    res = extractor.extract(text, module_name="supplier-entity")
    assert res["account_number"] == "0532013000"
    assert res["bank_account"] == "0532013000"
    assert res["swift_code"] == "COBADEFFXXX"
    assert res["iban"] == DE_IBAN


def test_iban_only_does_not_fill_account_number(extractor):
    res = extractor.extract(f"ACME Trading Ltd\nIBAN: {EG_IBAN}\nSWIFT: NBEGEGCX", module_name="bank-entity")
    assert res["iban"] == EG_IBAN
    assert res["account_number"] is None and res["bank_account"] is None
    assert res["swift_code"] == "NBEGEGCX"


def test_iban_written_under_account_label_goes_to_iban(extractor):
    res = extractor.extract(f"ACME Trading Ltd\nAccount Number: {EG_IBAN}")
    assert res["iban"] == EG_IBAN
    assert res["account_number"] is None


def test_unlabeled_iban_requires_valid_checksum(extractor):
    valid = extractor.extract(f"ACME Trading Ltd\nPay to {DE_IBAN} please")
    assert valid["iban"] == DE_IBAN
    broken = DE_IBAN[:-1] + ("1" if DE_IBAN[-1] != "1" else "2")
    invalid = extractor.extract(f"ACME Trading Ltd\nPay to {broken} please")
    assert invalid["iban"] is None


def test_arabic_bank_labels_with_eastern_digits(extractor):
    text = (
        "بنك مصر\n"
        "رقم الحساب: ١٩٠٣٠٠٠٥٠٠٠٠٢٦٣\n"
        "كود السويفت: BMISEGCX\n"
        f"الآيبان: {EG_IBAN}"
    )
    res = extractor.extract(text, module_name="bank-entity")
    assert res["account_number"] == "190300050000263"
    assert res["swift_code"] == "BMISEGCX"
    assert res["iban"] == EG_IBAN


def test_bic_label_is_not_matched_inside_words(extractor):
    res = extractor.extract("ACME Trading Ltd\nArabic: SOMETHING1\nCountry: Italy")
    assert res["swift_code"] is None


def test_iban_helpers():
    assert iban_checksum_valid(DE_IBAN) and iban_checksum_valid(EG_IBAN)
    assert not iban_checksum_valid("DE00370400440532013000")
    assert compact_iban_candidate(f"{DE_IBAN[:4]} {DE_IBAN[4:]} SWIFT") == DE_IBAN


@pytest.mark.parametrize(
    "text, key, expected",
    [
        ("WIPO Registration No.: 1587432", "wipo_number", "1587432"),
        ("WIPO International Registration Number 1587432", "wipo_number", "1587432"),
        ("رقم تسجيل الويبو: ١٥٨٧٤٣٢", "wipo_number", "1587432"),
        ("EUIPO Trade Mark No. 018234567", "euipo_number", "018234567"),
        ("EUTM: 018234567", "euipo_number", "018234567"),
        ("Global Brand Database ID: GBD-776655", "global_brand_number", "GBD-776655"),
        ("ISO 9001:2015 Certificate No: Q-12345", "iso_9001_number", "Q-12345"),
        ("ISO-9001 Cert. # QMS/2023/889", "iso_9001_number", "QMS/2023/889"),
        ("شهادة أيزو 9001: Q-55667", "iso_9001_number", "Q-55667"),
    ],
)
def test_trademark_certificate_numbers(extractor, text, key, expected):
    res = extractor.extract(f"ACME Trading Ltd\n{text}")
    assert res[key] == expected
    flag = {"wipo_number": "has_wipo", "euipo_number": "has_euipo",
            "global_brand_number": "has_global_brand", "iso_9001_number": "has_iso_9001"}[key]
    assert res[flag] is True


def test_iso_year_alone_is_not_a_certificate_number(extractor):
    res = extractor.extract("ACME Trading Ltd\nISO 9001:2015 certified manufacturer")
    assert res["has_iso_9001"] is True
    assert res["iso_9001_number"] is None


def test_wipo_label_word_is_not_returned_as_number(extractor):
    res = extractor.extract("ACME Trading Ltd\nWIPO Registration pending")
    assert res["wipo_number"] is None


def test_european_union_address_is_not_euipo(extractor):
    res = extractor.extract("ACME Trading Ltd\nالعنوان: ميلانو - إيطاليا - الاتحاد الأوروبي")
    assert res["has_euipo"] is False


def test_contact_fields_phone_mobile_fax_website_emails(extractor):
    text = (
        "Company Name: Delta Logistics LLC\n"
        "Tel/Fax: +20 3 4801234\n"
        "Mobile Phone: +20 100 123 4567\n"
        "Website: deltalogistics.com.eg\n"
        "Emails: ops@deltalogistics.com.eg, accounts@deltalogistics.com.eg\n"
        "Hotel 4455667788 booking"
    )
    res = extractor.extract(text, module_name="freight-forwarder-entity")
    assert res["phone_number"] == "+20 3 4801234"
    assert res["fax_number"] == "+20 3 4801234"
    assert res["mobile_number"] == "+20 100 123 4567"
    assert res["website"] == "deltalogistics.com.eg"
    assert res["email"] == "ops@deltalogistics.com.eg"
    assert res["secondary_email"] == "accounts@deltalogistics.com.eg"


def test_arabic_contact_labels(extractor):
    text = (
        "شركة الأمل للتجارة\n"
        "هاتف: ٠٢-٢٣٤٥٦٧٨٩\n"
        "موبايل: ٠١٠١٢٣٤٥٦٧٨\n"
        "فاكس: ٠٢-٢٣٤٥٦٧٠٠\n"
        "الموقع الإلكتروني: www.alamal-trade.com"
    )
    res = extractor.extract(text, module_name="supplier-entity")
    assert res["phone_number"] == "02-23456789"
    assert res["mobile_number"] == "01012345678"
    assert res["fax_number"] == "02-23456700"
    assert res["website"] == "www.alamal-trade.com"
    assert res["arabic_name"] == "شركة الأمل للتجارة"


def test_company_name_labels_english_and_arabic(extractor):
    assert extractor.extract("Legal Name: Orion Machinery GmbH\nCountry: Germany")["company_name"] == "Orion Machinery GmbH"
    res = extractor.extract("اسم الشركة: شركة الفجر للاستيراد\nCompany Name: Al Fagr Import Co.")
    assert res["company_name"] == "Al Fagr Import Co."
    assert res["arabic_name"] == "شركة الفجر للاستيراد"


def test_company_name_skips_ocr_noise_lines(extractor):
    res = extractor.extract("--- PAGE 1 ---\n||| 12 |||\nOrion Machinery\nCountry: Germany")
    assert res["company_name"] == "Orion Machinery"


def test_found_fields_lists_only_recognized_signal_fields(extractor):
    res = extractor.extract(SUPPLIER_CARD_TEXT, module_name="supplier-entity")
    found = extractor.found_fields(res)
    assert {"company_name", "cargox_id", "phone_number", "email"} <= set(found)
    # aliases / defaults are not counted
    assert "cargox_platform_id" not in found and "rating" not in found and "supplier_type" not in found


def test_parse_text_reports_fields_found():
    result = sdu_service.parse_raw_text_directly(
        db=_fallback_db(), module_name="supplier-entity", raw_text=SUPPLIER_CARD_TEXT,
    )
    assert "cargox_id" in result["fields_found"]
