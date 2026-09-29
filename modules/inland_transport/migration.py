import sqlite3

def run_migration():
    conn = sqlite3.connect('sorour_logistics.db')
    cursor = conn.cursor()

    # 1. Create inland_transport_bookings table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS inland_transport_bookings (
        transport_id INTEGER PRIMARY KEY AUTOINCREMENT,
        transport_code VARCHAR(50) UNIQUE NOT NULL,
        import_file_id INTEGER NOT NULL,
        waybill_number VARCHAR(100) NOT NULL,
        booking_date DATETIME NOT NULL,
        carrier_id INTEGER,
        carrier_name VARCHAR(255) NOT NULL,
        truck_plate_number VARCHAR(50) NOT NULL,
        truck_type VARCHAR(100) DEFAULT 'FLATBED',
        driver_name VARCHAR(100) NOT NULL,
        driver_phone VARCHAR(50) NOT NULL,
        driver_national_id VARCHAR(50),
        container_numbers VARCHAR(255),
        pickup_port_location VARCHAR(200) NOT NULL,
        destination_warehouse VARCHAR(200) NOT NULL,
        planned_departure_at DATETIME NOT NULL,
        actual_departure_at DATETIME,
        expected_arrival_at DATETIME NOT NULL,
        actual_arrival_at DATETIME,
        transport_fare_egp FLOAT DEFAULT 0.0,
        status VARCHAR(50) DEFAULT 'Booking Confirmed',
        tracking_notes TEXT,
        is_active BOOLEAN DEFAULT 1,
        created_at DATETIME,
        created_by VARCHAR(100) DEFAULT 'System',
        updated_at DATETIME,
        updated_by VARCHAR(100) DEFAULT 'System',
        FOREIGN KEY(import_file_id) REFERENCES import_files(import_file_id),
        FOREIGN KEY(carrier_id) REFERENCES external_service_providers(provider_id)
    )
    ''')

    cursor.execute('CREATE INDEX IF NOT EXISTS ix_inland_transport_code ON inland_transport_bookings(transport_code)')
    cursor.execute('CREATE INDEX IF NOT EXISTS ix_inland_transport_file_id ON inland_transport_bookings(import_file_id)')

    # 2. Add columns to import_files
    existing_cols = [c[1] for c in cursor.execute('PRAGMA table_info(import_files)').fetchall()]
    cols_to_add = [
        ('inland_transport_status', 'VARCHAR(50) DEFAULT "NOT_BOOKED"'),
        ('inland_transport_booking_no', 'VARCHAR(100)'),
        ('inland_carrier_name', 'VARCHAR(255)'),
        ('inland_truck_plate_no', 'VARCHAR(50)'),
        ('inland_driver_name', 'VARCHAR(100)'),
        ('inland_driver_phone', 'VARCHAR(50)'),
        ('inland_transport_cost_egp', 'FLOAT DEFAULT 0.0'),
        ('inland_departure_date', 'DATETIME'),
        ('inland_expected_arrival_date', 'DATETIME'),
        ('inland_actual_arrival_date', 'DATETIME'),
    ]

    for col_name, col_def in cols_to_add:
        if col_name not in existing_cols:
            cursor.execute(f'ALTER TABLE import_files ADD COLUMN {col_name} {col_def}')
            print(f'Added column import_files.{col_name}')
        else:
            print(f'Column import_files.{col_name} already exists')

    conn.commit()
    conn.close()
    print('Migration completed successfully!')

if __name__ == '__main__':
    run_migration()
