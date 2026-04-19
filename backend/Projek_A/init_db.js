const mysql = require('mysql');

const db = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'smart_cooks',
    multipleStatements: true
});

function query(sql) {
    return new Promise((resolve, reject) => {
        db.query(sql, (error, elements) => {
            if (error) { return reject(error); }
            return resolve(elements);
        });
    });
}

async function initDB() {
    try {
        db.connect();
        console.log("Memulai proses Drop (Menghapus) tabel lama...");

        await query("SET FOREIGN_KEY_CHECKS = 0;");

        const dropTables = [
            'makanan_tag', 'tag', 'makanan_kategori', 'kategori_makanan', 'langkah_resep',
            'resep_bahan', 'resep', 'favorit', 'resep_reaction', 'histori_resep',
            'makanan', 'deteksi_detail', 'bahan', 'kategori_bahan', 'deteksi_bahan',
            'search_log', 'users'
        ];

        for (let table of dropTables) {
            await query(`DROP TABLE IF EXISTS ${table};`);
            console.log(`- Tabel ${table} dihapus (jika ada).`);
        }

        console.log("\nMemulai proses Create (Membuat) 16 tabel baru...");

        // 1. users
        await query(`
            CREATE TABLE users (
                id_user INT AUTO_INCREMENT PRIMARY KEY,
                nama VARCHAR(100) NOT NULL,
                email VARCHAR(100) NOT NULL UNIQUE,
                password VARCHAR(255) NOT NULL,
                role ENUM('user', 'admin') DEFAULT 'user',
                foto_profil VARCHAR(255) DEFAULT '',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        `);
        console.log("1. Tabel users berhasil dibuat.");

        // 2. makanan (Ditambah status dan pencipta untuk filter Sandbox AI)
        await query(`
            CREATE TABLE makanan (
                id_makanan INT AUTO_INCREMENT PRIMARY KEY,
                nama_makanan VARCHAR(150) NOT NULL,
                deskripsi TEXT,
                foto_utama VARCHAR(255) DEFAULT '',
                total_view INT DEFAULT 0,
                total_like INT DEFAULT 0,
                url_video VARCHAR(255) DEFAULT '',
                caption VARCHAR(255) DEFAULT '',
                status ENUM('published', 'pending', 'private') DEFAULT 'published',
                pencipta VARCHAR(100) DEFAULT 'Admin',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `);
        console.log("2. Tabel makanan berhasil dibuat.");

        // 3. resep
        await query(`
            CREATE TABLE resep (
                id_resep INT AUTO_INCREMENT PRIMARY KEY,
                id_makanan INT NOT NULL,
                deskripsi TEXT,
                waktu_masak INT DEFAULT 0,
                tingkat_kesulitan ENUM('mudah', 'sedang', 'sulit') DEFAULT 'mudah',
                kalori INT DEFAULT 0,
                created_by INT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (id_makanan) REFERENCES makanan(id_makanan) ON DELETE CASCADE,
                FOREIGN KEY (created_by) REFERENCES users(id_user) ON DELETE SET NULL
            )
        `);
        console.log("3. Tabel resep berhasil dibuat.");

        // 4. kategori_makanan
        await query(`
            CREATE TABLE kategori_makanan (
                id_kategori INT AUTO_INCREMENT PRIMARY KEY,
                nama_kategori VARCHAR(100) NOT NULL,
                deskripsi TEXT,
                icon VARCHAR(255) DEFAULT '',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `);
        console.log("4. Tabel kategori_makanan berhasil dibuat.");

        // 5. makanan_kategori
        await query(`
            CREATE TABLE makanan_kategori (
                id INT AUTO_INCREMENT PRIMARY KEY,
                id_makanan INT NOT NULL,
                id_kategori INT NOT NULL,
                FOREIGN KEY (id_makanan) REFERENCES makanan(id_makanan) ON DELETE CASCADE,
                FOREIGN KEY (id_kategori) REFERENCES kategori_makanan(id_kategori) ON DELETE CASCADE
            )
        `);
        console.log("5. Tabel makanan_kategori berhasil dibuat.");

        // 6. tag
        await query(`
            CREATE TABLE tag (
                id_tag INT AUTO_INCREMENT PRIMARY KEY,
                nama_tag VARCHAR(100) NOT NULL UNIQUE
            )
        `);
        console.log("6. Tabel tag berhasil dibuat.");

        // 7. makanan_tag
        await query(`
            CREATE TABLE makanan_tag (
                id INT AUTO_INCREMENT PRIMARY KEY,
                id_makanan INT NOT NULL,
                id_tag INT NOT NULL,
                FOREIGN KEY (id_makanan) REFERENCES makanan(id_makanan) ON DELETE CASCADE,
                FOREIGN KEY (id_tag) REFERENCES tag(id_tag) ON DELETE CASCADE
            )
        `);
        console.log("7. Tabel makanan_tag berhasil dibuat.");

        // 8. kategori_bahan
        await query(`
            CREATE TABLE kategori_bahan (
                id_kategori_bahan INT AUTO_INCREMENT PRIMARY KEY,
                nama_kategori VARCHAR(100) NOT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `);
        console.log("8. Tabel kategori_bahan berhasil dibuat.");

        // 9. bahan
        await query(`
            CREATE TABLE bahan (
                id_bahan INT AUTO_INCREMENT PRIMARY KEY,
                nama_bahan VARCHAR(100) NOT NULL UNIQUE,
                id_kategori_bahan INT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (id_kategori_bahan) REFERENCES kategori_bahan(id_kategori_bahan) ON DELETE SET NULL
            )
        `);
        console.log("9. Tabel bahan berhasil dibuat.");

        // 10. resep_bahan (Tetap pakai jumlah: varchar untuk mempermudah porsi)
        await query(`
            CREATE TABLE resep_bahan (
                id INT AUTO_INCREMENT PRIMARY KEY,
                id_resep INT NOT NULL,
                id_bahan INT NOT NULL,
                jumlah VARCHAR(50) DEFAULT '',
                tipe ENUM('utama', 'pendukung') DEFAULT 'utama',
                FOREIGN KEY (id_resep) REFERENCES resep(id_resep) ON DELETE CASCADE,
                FOREIGN KEY (id_bahan) REFERENCES bahan(id_bahan) ON DELETE CASCADE
            )
        `);
        console.log("10. Tabel resep_bahan berhasil dibuat.");

        // 11. langkah_resep
        await query(`
            CREATE TABLE langkah_resep (
                id_langkah INT AUTO_INCREMENT PRIMARY KEY,
                id_resep INT NOT NULL,
                urutan_step INT NOT NULL,
                deskripsi_step TEXT NOT NULL,
                foto_step VARCHAR(255) DEFAULT '',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (id_resep) REFERENCES resep(id_resep) ON DELETE CASCADE
            )
        `);
        console.log("11. Tabel langkah_resep berhasil dibuat.");

        // 12. favorit
        await query(`
            CREATE TABLE favorit (
                id INT AUTO_INCREMENT PRIMARY KEY,
                id_user INT NOT NULL,
                id_makanan INT NOT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE CASCADE,
                FOREIGN KEY (id_makanan) REFERENCES makanan(id_makanan) ON DELETE CASCADE
            )
        `);
        console.log("12. Tabel favorit berhasil dibuat.");

        // 13. resep_reaction
        await query(`
            CREATE TABLE resep_reaction (
                id INT AUTO_INCREMENT PRIMARY KEY,
                id_user INT NOT NULL,
                id_makanan INT NOT NULL,
                reaction_type ENUM('like', 'love', 'clap') NOT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE CASCADE,
                FOREIGN KEY (id_makanan) REFERENCES makanan(id_makanan) ON DELETE CASCADE
            )
        `);
        console.log("13. Tabel resep_reaction berhasil dibuat.");

        // 14. histori_resep
        await query(`
            CREATE TABLE histori_resep (
                id INT AUTO_INCREMENT PRIMARY KEY,
                id_user INT NOT NULL,
                id_resep INT NOT NULL,
                viewed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE CASCADE,
                FOREIGN KEY (id_resep) REFERENCES resep(id_resep) ON DELETE CASCADE
            )
        `);
        console.log("14. Tabel histori_resep berhasil dibuat.");

        // 15. search_log
        await query(`
            CREATE TABLE search_log (
                id INT AUTO_INCREMENT PRIMARY KEY,
                id_user INT NOT NULL,
                keyword VARCHAR(255) NOT NULL,
                searched_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE CASCADE
            )
        `);
        console.log("15. Tabel search_log berhasil dibuat.");

        // 16. deteksi_bahan & deteksi_detail
        await query(`
            CREATE TABLE deteksi_bahan (
                id_deteksi INT AUTO_INCREMENT PRIMARY KEY,
                id_user INT NOT NULL,
                gambar_path VARCHAR(255) DEFAULT '',
                confidence_score FLOAT DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE CASCADE
            )
        `);
        
        await query(`
            CREATE TABLE deteksi_detail (
                id INT AUTO_INCREMENT PRIMARY KEY,
                id_deteksi INT NOT NULL,
                id_bahan INT NOT NULL,
                confidence FLOAT DEFAULT 0,
                FOREIGN KEY (id_deteksi) REFERENCES deteksi_bahan(id_deteksi) ON DELETE CASCADE,
                FOREIGN KEY (id_bahan) REFERENCES bahan(id_bahan) ON DELETE CASCADE
            )
        `);
        console.log("16. Tabel deteksi_bahan & deteksi_detail berhasil dibuat.");

        // Mengaktifkan kembali foreign key checks
        await query("SET FOREIGN_KEY_CHECKS = 1;");

        console.log("\n=============================================");
        console.log("✅ SUKSES! Seluruh tabel berhasil dibuat ulang!");
        console.log("Struktur database Anda kini memiliki 'pencipta' dan 'status' (Sandbox)!");
        console.log("=============================================\n");

        process.exit(0);

    } catch (err) {
        console.error("❌ Terjadi Kesalahan saat inisialisasi tabel:", err);
        process.exit(1);
    }
}

initDB();
