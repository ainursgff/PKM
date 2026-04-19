const express = require('express');
const router = express.Router();
const db = require('../config/db');

// Fungsi eksekusi query dengan Promise khusus untuk Transaction
function queryTransaction(conn, sql, params = []) {
    return new Promise((resolve, reject) => {
        conn.query(sql, params, (err, rows) => {
            if (err) return reject(err);
            resolve(rows);
        });
    });
}

router.post('/generate-recipe', async (req, res) => {
    const listBahan = req.body.bahan_bahan; // Expect array e.g. ["Ayam", "Bawang"]

    if (!listBahan || !Array.isArray(listBahan) || listBahan.length === 0) {
        return res.status(400).json({ error: "Kolom bahan_bahan (array) wajib diisi." });
    }

    try {
        // 1. Memanggil Gemini AI
        const prompt = `
Kamu adalah The Master Chef yang menjunjung tinggi keaslian kuliner.
TUGAS UTAMA: Buatkan resep makanan NYATA dan AUTENTIK yang menggunakan semua atau sebagian besar bahan berikut: ${listBahan.join(', ')}.

ATURAN ANTI-HALUSINASI (SANGAT PENTING):
1. UTAMAKAN KULINER NYATA: Pastikan resep yang kamu berikan benar-benar eksis di dunia nyata. Jangan mengarang nama makanan yang aneh.
2. JIKA BAHAN TIDAK COCOK: Jika bahan-bahan yang diberikan sama sekali tidak wajar untuk digabungkan dalam resep asli mana pun, JANGAN memaksakan resep tradisional. Sebagai gantinya, buatlah resep baru berupa "Kreasi Eksperimental AI" yang tetap masuk akal dan lezat dimakan.
3. TANDA KREASI AI: Jika kamu terpaksa membuat resep Kreasi Eksperimental, WAJIB awali isi teks pada atribut "deskripsi" dengan awalan eksak: "[Kreasi Eksperimental AI] ".

ATURAN GAMBAR (SANGAT PENTING):
4. SERTAKAN URL GAMBAR ASLI: Kamu WAJIB menyertakan atribut "gambar_url" berisi URL gambar foto makanan yang NYATA dari internet (misalnya dari situs resep ternama seperti cookpad.com, masakapahariini.com, atau sumber terpercaya lainnya). URL harus berakhiran format gambar (.jpg, .jpeg, .png, .webp) atau berupa direct link ke gambar yang bisa ditampilkan langsung. Jika tidak bisa menemukan URL gambar yang valid, isi dengan string kosong "".
5. SERTAKAN SUMBER: Kamu WAJIB menyertakan atribut "sumber_resep" berisi nama sumber referensi resep (misal: "Cookpad - Chef Juna", "Resep Ibunda Nusantara", dll). Jika resep adalah kreasi AI, isi dengan "Kreasi AI: Gemini".

Keluarkan hasilnya HANYA dalam FORMAT JSON MURNI (tanpa markdown, tanpa backticks). Struktur json yang wajib kamu penuhi:
{
    "nama_makanan": "Contoh: Rendang Sapi Asli Padang",
    "deskripsi": "Deskripsi kelezatan resep ini",
    "gambar_url": "https://contoh.com/gambar-makanan.jpg",
    "sumber_resep": "Nama sumber resep atau kredit pencipta",
    "waktu_masak": 60,
    "tingkat_kesulitan": "sedang",
    "kalori": 550,
    "bahan_bahan": [
        {"nama": "Daging Sapi", "jumlah": "500 gram", "tipe": "utama"},
        {"nama": "Santan Kelapa", "jumlah": "500 ml", "tipe": "pendukung"}
    ],
    "langkah": [
        "Cuci bersih bahan utama.",
        "Tumis bumbu halus hingga harum."
    ],
    "kategori": ["Tradisional", "Lauk"]
}
`;

        const response = await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent", {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': process.env.GEMINI_API_KEY.trim()
            },
            body: JSON.stringify({
                contents: [
                    {
                        parts: [{ text: prompt }]
                    }
                ],
                generationConfig: {
                    responseMimeType: "application/json"
                }
            })
        });

        const replyData = await response.json();

        if (!response.ok) {
            console.error("Gemini API Error:", replyData);
            return res.status(500).json({ error: "Gagal dari server AI", detail: replyData.error?.message || '' });
        }

        // 2. Parse hasil JSON dari AI
        let recipeData;
        try {
            const rawText = replyData.candidates[0].content.parts[0].text;
            recipeData = JSON.parse(rawText);
        } catch (e) {
            console.error("Gagal parse JSON Gemini:", replyData);
            return res.status(500).json({ error: "Format respons dari AI tidak valid." });
        }

        console.log("✅ Resep AI diterima:", recipeData.nama_makanan);
        console.log("   Gambar URL:", recipeData.gambar_url || "(tidak ada)");
        console.log("   Sumber:", recipeData.sumber_resep || "(tidak ada)");

        // --- 3. MULAI DATABASE TRANSACTION ---
        db.pool.getConnection((err, conn) => {
            if (err) {
                console.error("Gagal mendapatkan koneksi db:", err);
                return res.status(500).json({ error: "Database error" });
            }

            conn.beginTransaction(async (err) => {
                if (err) {
                    conn.release();
                    return res.status(500).json({ error: "Gagal memulai transaksi" });
                }

                try {
                    // a) INSERT Makanan (Status: pending, Pencipta: AI Gemini, foto_utama: URL dari AI)
                    const fotoUtama = recipeData.gambar_url || '';
                    const resMakanan = await queryTransaction(conn, `
                        INSERT INTO makanan (nama_makanan, deskripsi, foto_utama, status, pencipta) 
                        VALUES (?, ?, ?, 'pending', 'AI Gemini')
                    `, [recipeData.nama_makanan, recipeData.deskripsi, fotoUtama]);
                    const idMakanan = resMakanan.insertId;

                    // b) INSERT Resep
                    const idUser = req.body.id_user || null;
                    let kesulitan = ['mudah', 'sedang', 'sulit'].includes(recipeData.tingkat_kesulitan?.toLowerCase())
                        ? recipeData.tingkat_kesulitan.toLowerCase() : 'mudah';

                    const resResep = await queryTransaction(conn, `
                        INSERT INTO resep (id_makanan, deskripsi, waktu_masak, tingkat_kesulitan, kalori, created_by) 
                        VALUES (?, ?, ?, ?, ?, ?)
                    `, [idMakanan, recipeData.deskripsi, recipeData.waktu_masak || 0, kesulitan, recipeData.kalori || 0, idUser]);
                    const idResep = resResep.insertId;

                    // c) INSERT Kategori & makanan_kategori
                    if (Array.isArray(recipeData.kategori)) {
                        for (let catName of recipeData.kategori) {
                            let cats = await queryTransaction(conn, `SELECT id_kategori FROM kategori_makanan WHERE nama_kategori = ?`, [catName]);
                            let idKategori;
                            if (cats.length > 0) {
                                idKategori = cats[0].id_kategori;
                            } else {
                                let insCat = await queryTransaction(conn, `INSERT INTO kategori_makanan (nama_kategori) VALUES (?)`, [catName]);
                                idKategori = insCat.insertId;
                            }
                            await queryTransaction(conn, `INSERT INTO makanan_kategori (id_makanan, id_kategori) VALUES (?, ?)`, [idMakanan, idKategori]);
                        }
                    }

                    // d) INSERT Bahan & resep_bahan
                    if (Array.isArray(recipeData.bahan_bahan)) {
                        for (let item of recipeData.bahan_bahan) {
                            let namaBahan = item.nama;
                            let bhn = await queryTransaction(conn, `SELECT id_bahan FROM bahan WHERE nama_bahan = ?`, [namaBahan]);
                            let idBahan;
                            if (bhn.length > 0) {
                                idBahan = bhn[0].id_bahan;
                            } else {
                                let insBhn = await queryTransaction(conn, `INSERT INTO bahan (nama_bahan) VALUES (?)`, [namaBahan]);
                                idBahan = insBhn.insertId;
                            }

                            let tipe = ['utama', 'pendukung'].includes(item.tipe?.toLowerCase()) ? item.tipe.toLowerCase() : 'utama';
                            await queryTransaction(conn, `INSERT INTO resep_bahan (id_resep, id_bahan, jumlah, tipe) VALUES (?, ?, ?, ?)`, [idResep, idBahan, item.jumlah || '', tipe]);
                        }
                    }

                    // e) INSERT Langkah_Resep
                    if (Array.isArray(recipeData.langkah)) {
                        let stepCounter = 1;
                        for (let l of recipeData.langkah) {
                            await queryTransaction(conn, `INSERT INTO langkah_resep (id_resep, urutan_step, deskripsi_step) VALUES (?, ?, ?)`, [idResep, stepCounter, l]);
                            stepCounter++;
                        }
                    }

                    // SUKSES: Lakukan Commit
                    conn.commit((err) => {
                        if (err) {
                            return conn.rollback(() => {
                                conn.release();
                                throw err;
                            });
                        }
                        conn.release();
                        // Kirim Respons Sukses beserta data lengkap
                        return res.json({
                            message: "Resep AI sukses dibuat dan dikarantina (pending_review).",
                            id_makanan: idMakanan,
                            id_resep: idResep,
                            data: recipeData
                        });
                    });

                } catch (txError) {
                    console.error("Gagal saat menyimpan data resep:", txError);
                    conn.rollback(() => {
                        conn.release();
                        return res.status(500).json({ error: "Gagal menyimpan resep ke database." });
                    });
                }
            });
        });

    } catch (error) {
        console.error("Error API Gemini:", error);
        res.status(500).json({ error: "Gagal memanggil API Gemini." });
    }
});

module.exports = router;
