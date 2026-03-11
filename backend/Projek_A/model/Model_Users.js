const db = require('../config/db');
const bcrypt = require('bcrypt');

class Model_Users {

static async login(email,password){

    const rows = await db.query(
        "SELECT * FROM users WHERE email=? LIMIT 1",
        [email]
    );

    if(rows.length === 0){
        return null;
    }

    const user = rows[0];

    const match = await bcrypt.compare(password,user.password);

    if(!match){
        return null;
    }

    delete user.password;

    return user;
}

static async register(data){

    const hash = await bcrypt.hash(data.password,10);

    const res = await db.query(
        `INSERT INTO users
        (nama,email,password,role)
        VALUES (?,?,?,?)`,
        [
            data.nama,
            data.email,
            hash,
            'user'
        ]
    );

    return res.insertId;
}

}

module.exports = Model_Users;