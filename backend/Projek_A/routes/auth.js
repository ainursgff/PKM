const express = require('express');
const router = express.Router();

const Users = require('../model/Model_Users');


/// REGEX EMAIL VALID
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;



router.post('/login', async (req,res)=>{

try{

    const {email,password} = req.body;

    if(!email || !password){

        return res.status(400).json({
            message:"Email dan password wajib diisi"
        });

    }

    const user = await Users.login(email,password);

    if(!user){

        return res.status(401).json({
            message:"Email atau password salah"
        });

    }

    res.json({
        message:"Login berhasil",
        user:user
    });

}catch(e){

    console.log(e);

    res.status(500).json({
        message:"Server error"
    });

}

});



router.post('/register',async(req,res)=>{

try{

    const {nama,email,password} = req.body;

    /// VALIDASI KOSONG
    if(!nama || !email || !password){

        return res.status(400).json({
            message:"Semua field wajib diisi"
        });

    }

    /// VALIDASI EMAIL FORMAT
    if(!emailRegex.test(email)){

        return res.status(400).json({
            message:"Format email tidak valid"
        });

    }

    /// VALIDASI PASSWORD
    if(password.length < 6){

        return res.status(400).json({
            message:"Password minimal 6 karakter"
        });

    }

    /// SIMPAN USER
    const id = await Users.register({
        nama,
        email,
        password
    });

    res.json({
        message:"Register berhasil",
        id:id
    });

}catch(e){

    console.log(e);

    res.status(500).json({
        message:"Register gagal"
    });

}

});

module.exports = router;