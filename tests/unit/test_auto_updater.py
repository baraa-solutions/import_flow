"""
Unit Tests — Auto-Update Engine (BP-009)
Tests: installer info fetching, check_for_updates installer fields, InstallerInfoSchema
"""
import json
import sys
import os
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock, mock_open

# Add root to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from modules.production_sync.schemas import InstallerInfoSchema, RemoteUpdateCheckSchema


class TestInstallerInfoSchema(unittest.TestCase):
    """Tests for InstallerInfoSchema Pydantic model."""

    def test_valid_installer_info(self):
        info = InstallerInfoSchema(
            version="1.0.89",
            installer_url="https://github.com/ahmedsalahsorour88/import_flow/releases/download/v1.0.89/Sorour_Logistics_Setup_v1.0.89.exe",
            installer_filename="Sorour_Logistics_Setup_v1.0.89.exe",
            installer_size_mb=210.5,
            is_available=True,
        )
        self.assertEqual(info.version, "1.0.89")
        self.assertTrue(info.is_available)
        self.assertAlmostEqual(info.installer_size_mb, 210.5)
        self.assertIsNone(info.error)

    def test_unavailable_installer_info(self):
        info = InstallerInfoSchema(
            version="unknown",
            installer_url="",
            installer_filename="",
            is_available=False,
            error="Connection failed",
        )
        self.assertFalse(info.is_available)
        self.assertEqual(info.error, "Connection failed")
        self.assertEqual(info.installer_url, "")

    def test_installer_size_mb_defaults_to_zero(self):
        info = InstallerInfoSchema(
            version="1.0.88",
            installer_url="https://example.com/setup.exe",
            installer_filename="setup.exe",
        )
        self.assertEqual(info.installer_size_mb, 0.0)


class TestRemoteUpdateCheckSchemaInstallerFields(unittest.TestCase):
    """Tests for RemoteUpdateCheckSchema with installer fields."""

    def test_has_installer_url_fields(self):
        schema = RemoteUpdateCheckSchema(
            has_update=True,
            current_version="1.0.88",
            latest_version="1.0.89",
            installer_url="https://github.com/ahmedsalahsorour88/import_flow/releases/download/v1.0.89/Sorour_Logistics_Setup_v1.0.89.exe",
            installer_filename="Sorour_Logistics_Setup_v1.0.89.exe",
            installer_size_mb=210.5,
            check_status="UPDATE_AVAILABLE",
            message="Update available",
        )
        self.assertTrue(schema.has_update)
        self.assertEqual(schema.installer_url, "https://github.com/ahmedsalahsorour88/import_flow/releases/download/v1.0.89/Sorour_Logistics_Setup_v1.0.89.exe")
        self.assertEqual(schema.installer_filename, "Sorour_Logistics_Setup_v1.0.89.exe")
        self.assertAlmostEqual(schema.installer_size_mb, 210.5)

    def test_installer_fields_optional(self):
        schema = RemoteUpdateCheckSchema(
            has_update=False,
            current_version="1.0.88",
            latest_version="1.0.88",
            check_status="UP_TO_DATE",
            message="System is up to date",
        )
        self.assertIsNone(schema.installer_url)
        self.assertIsNone(schema.installer_filename)
        self.assertEqual(schema.installer_size_mb, 0.0)


class TestGetLatestInstallerInfo(unittest.TestCase):
    """Tests for ProductionSyncService.get_latest_installer_info()."""

    def _get_service(self):
        from modules.production_sync.service import ProductionSyncService
        mock_db = MagicMock()
        return ProductionSyncService(mock_db)

    def test_installer_info_is_local_only(self):
        """No installer is offered by production_sync any more (updates come from app_update)."""
        with patch("urllib.request.urlopen") as mock_urlopen:
            service = self._get_service()
            with patch.object(service, "get_system_version_info") as mock_version:
                mock_version.return_value = MagicMock(version="1.0.88")
                result = service.get_latest_installer_info()

        mock_urlopen.assert_not_called()
        self.assertFalse(result.is_available)
        self.assertEqual(result.version, "1.0.88")
        self.assertEqual(result.installer_url, "")
        self.assertEqual(result.installer_filename, "")
        self.assertTrue(result.error)

    def test_installer_info_ignores_installer_url_in_local_version_json(self):
        """Even a local version.json with installer_url no longer yields a download link."""
        local_data = json.dumps({"version": "1.0.88", "installer_url": "https://example.com/setup.exe"})
        with patch("urllib.request.urlopen") as mock_urlopen, patch("builtins.open", mock_open(read_data=local_data)):
            result = self._get_service().get_latest_installer_info()
        mock_urlopen.assert_not_called()
        self.assertFalse(result.is_available)
        self.assertEqual(result.installer_url, "")


class TestCheckForUpdatesInstallerFields(unittest.TestCase):
    """Tests that check_for_updates populates installer fields correctly."""

    def _get_service(self):
        from modules.production_sync.service import ProductionSyncService
        mock_db = MagicMock()
        return ProductionSyncService(mock_db)

    def test_check_for_updates_is_local_only(self):
        """check-updates no longer contacts any server (updates come from app_update)."""
        with patch("urllib.request.urlopen") as mock_urlopen:
            service = self._get_service()
            with patch.object(service, "get_system_version_info") as mock_version:
                mock_version.return_value = MagicMock(version="1.0.88")
                result = service.check_for_updates()

        mock_urlopen.assert_not_called()
        self.assertFalse(result.has_update)
        self.assertEqual(result.current_version, "1.0.88")
        self.assertEqual(result.latest_version, "1.0.88")
        self.assertEqual(result.check_status, "UP_TO_DATE")

    def test_check_for_updates_rejects_custom_remote_url_argument(self):
        with self.assertRaises(TypeError):
            self._get_service().check_for_updates(custom_remote_url="https://evil.example/version.json")

if __name__ == "__main__":
    unittest.main()
