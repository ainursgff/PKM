const mysql = require('mysql');

const pool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'smart_cooks',
    multipleStatements: true
});

pool.getConnection((err, conn) => {
    if (err) {
        console.error('Database gagal terhubung !', err.message);
    } else {
        console.log('Sip, Database Berhasil Terhubung !');
        conn.release();
    }
});

module.exports = {
    query(sql, params = []) {
        return new Promise((resolve, reject) => {
            pool.getConnection((err, conn) => {
                if (err) return reject(err);
                conn.query(sql, params, (qErr, rows) => {
                    conn.release();
                    if (qErr) return reject(qErr);
                    resolve(rows);
                });
            });
        });
    }
};