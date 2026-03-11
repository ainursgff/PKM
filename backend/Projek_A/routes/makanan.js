// routes/makanan.js
const express = require('express');
const router  = express.Router();

const Makanan = require('../model/Model_Makanan');

function cleanFilename(name){
  return String(name || '').trim().replace(/[^0-9A-Za-z._ -]/g,'');
}


// ==== LIST DATA ====
router.get('/', async (req,res) => {

  try{

    const rows = await Makanan.getAll();

    res.json(rows);

  }catch(e){

    console.error("Load makanan error:",e);

    res.status(500).json({
      message:"Gagal memuat data makanan"
    });

  }

});


// ==== DETAIL ====
router.get('/:id', async (req,res)=>{

  try{

    const row = await Makanan.getById(Number(req.params.id));

    if(!row)
      return res.json({message:"Data tidak ditemukan"});

    res.json(row);

  }catch(e){

    console.error("Detail makanan error:",e);

    res.status(500).json({
      message:"Gagal mengambil data"
    });

  }

});


// ==== CREATE ====
router.post('/create', async (req,res)=>{

  try{

    const id = await Makanan.create({

      nama_makanan : (req.body.nama_makanan||'').trim(),
      deskripsi    : (req.body.deskripsi||'').trim(),
      foto_utama       : cleanFilename(req.body.gambar||'')

    });

    res.json({
      message:"Makanan berhasil ditambahkan",
      id
    });

  }catch(e){

    console.error("Create makanan error:",e);

    res.status(500).json({
      message:e.message || "Gagal menambah data"
    });

  }

});


// ==== UPDATE ====
router.post('/edit/:id', async (req,res)=>{

  try{

    const ok = await Makanan.update(Number(req.params.id),{

      nama_makanan : (req.body.nama_makanan||'').trim(),
      deskripsi    : (req.body.deskripsi||'').trim(),
      foto_utama       : cleanFilename(req.body.foto_utama||'')

    });

    if(!ok)
      throw new Error("Data tidak ditemukan atau tidak berubah");

    res.json({
      message:"Data berhasil diupdate"
    });

  }catch(e){

    console.error("Update makanan error:",e);

    res.status(500).json({
      message:e.message || "Gagal update data"
    });

  }

});


// ==== DELETE ====
router.post('/delete/:id', async (req,res)=>{

  try{

    await Makanan.remove(Number(req.params.id));

    res.json({
      message:"Data makanan dihapus"
    });

  }catch(e){

    console.error("Delete makanan error:",e);

    res.status(500).json({
      message:"Gagal menghapus data"
    });

  }

});


module.exports = router;