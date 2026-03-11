const db = require('../config/db');

class Model_Makanan {

    // ---------- READ ----------
    static async getAll() {
        return db.query(`
            SELECT id_makanan, nama_makanan, deskripsi, foto_utama, url_video, caption
            FROM makanan
            ORDER BY nama_makanan ASC
        `);
    }

    static async getId(id) {
        const rows = await db.query(`
            SELECT id_makanan, nama_makanan, deskripsi, foto_utama, url_video, caption
            FROM makanan
            WHERE id_makanan = ?
            LIMIT 1
        `,[id]);

        return rows[0] || null;
    }

    static async getById(id){
        return this.getId(id);
    }

    // ---------- UTIL ----------
    static toRow(data){

        data = data || {};

        const nama_makanan = String(data.nama_makanan || '').trim();
        const deskripsi = String(data.deskripsi || '').trim();
        const foto_utama = String(data.foto_utama || '').trim();
        const url_video = String(data.url_video || '').trim();
        const caption = String(data.caption || '').trim();

        return { nama_makanan, deskripsi, foto_utama, url_video, caption };
    }

    // ---------- CREATE ----------
static async Store(data){

    const row = this.toRow(data);

    if(!row.nama_makanan)
        throw new Error('nama_makanan wajib diisi.');

    return db.query(`
        INSERT INTO makanan
        (nama_makanan, deskripsi, foto_utama, url_video, caption)
        VALUES (?,?,?,?,?)
    `,[
        row.nama_makanan,
        row.deskripsi,
        row.foto_utama,
        data.url_video || '',
        data.caption || ''
    ]);
}

    static async create(data){
        const res = await this.Store(data);
        return res.insertId;
    }

    // ---------- UPDATE ----------
    static async Update(id,data){

        const row = this.toRow(data);

        if(!row.nama_makanan)
            throw new Error('nama_makanan wajib diisi.');

const res = await db.query(`
UPDATE makanan
SET nama_makanan=?, deskripsi=?, foto_utama=?, url_video=?, caption=?
WHERE id_makanan=?
`,[
row.nama_makanan,
row.deskripsi,
row.foto_utama,
row.url_video,
row.caption,
id
]);

        return { affectedRows : (res && res.affectedRows) ? res.affectedRows : 0 };
    }

    static async update(id,data){
        const r = await this.Update(id,data);
        return r.affectedRows > 0;
    }

    // ---------- DELETE ----------
    static async Delete(id){
        return db.query(`
            DELETE FROM makanan
            WHERE id_makanan=?
        `,[id]);
    }

    static async remove(id){
        await this.Delete(id);
        return true;
    }

}

module.exports = Model_Makanan;