const express = require('express');
const router = express.Router();
const multer = require('multer');
const http = require('http'); // Built-in Node JS http client
const path = require('path');
const fs = require('fs');

const uploadDir = path.join(__dirname, '../uploads');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir);
}

const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        cb(null, 'img_' + Date.now() + path.extname(file.originalname));
    }
});
const upload = multer({ storage: storage });

router.post('/', upload.single('image'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'Tidak ada gambar yang diunggah' });
    }

    const imagePath = req.file.path;
    const fileSize = req.file.size;
    const mimeType = req.file.mimetype;
    const origName = req.file.originalname;
    console.log(`[DETECT] Received: ${origName} | ${(fileSize/1024).toFixed(1)} KB | ${mimeType} | saved: ${path.basename(imagePath)}`);
    
    // Kirim HTTP JSON Request ke Python AI Microservice di port 5001
    const postData = JSON.stringify({ image_path: imagePath });

    const options = {
        hostname: '127.0.0.1',
        port: 5001,
        path: '/',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(postData)
        }
    };

    const pyReq = http.request(options, (pyRes) => {
        let responseBody = '';

        pyRes.on('data', (chunk) => {
            responseBody += chunk;
        });

        pyRes.on('end', () => {
            // Hapus gambar setelah diproses AI
            if (fs.existsSync(imagePath)) {
                fs.unlinkSync(imagePath);
            }

            if (pyRes.statusCode === 200) {
                try {
                    const detections = JSON.parse(responseBody);
                    res.json(detections);
                } catch (e) {
                    console.error("Gagal parse response dari Python server:", e, responseBody);
                    res.status(500).json({ error: 'Data JSON dari AI tidak valid' });
                }
            } else {
                console.error("Python Server merespon Error HTTP:", pyRes.statusCode, responseBody);
                try {
                    const errObj = JSON.parse(responseBody);
                    res.status(500).json(errObj);
                } catch {
                    res.status(500).json({ error: 'Kesalahan internal AI Server' });
                }
            }
        });
    });

    pyReq.on('error', (e) => {
        // Hapus gambar jika gagal connect ke Python
        if (fs.existsSync(imagePath)) {
            fs.unlinkSync(imagePath);
        }
        console.error("Gagal terhubung ke AI Microservice (Port 5001):", e);
        res.status(500).json({ error: 'AI Microservice belum menyala (Cold-Start gagal)' });
    });

    pyReq.write(postData);
    pyReq.end();
});

module.exports = router;
