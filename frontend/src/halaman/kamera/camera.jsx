import { useState, useRef, useEffect } from 'react';
import { ArrowLeft, Camera, RefreshCw, Loader2, Maximize, X, Image as ImageIcon, CheckCircle, Sparkles, ChevronRight } from 'lucide-react';
import ApiService from '../../services/api_service';
import EditIngredients from './edit';
import './camera.css';

export default function CameraModal({ onClose }) {
  const videoRef = useRef(null);
  const canvasRef = useRef(null);
  const fileInputRef = useRef(null);
  const streamRef = useRef(null);
  
  const [stream, setStream] = useState(null);
  const [capturedImage, setCapturedImage] = useState(null); // For single camera capture
  const [isDetecting, setIsDetecting] = useState(false);
  const [results, setResults] = useState(null); // Results for camera capture
  const [errorMsg, setErrorMsg] = useState('');
  const [imageSize, setImageSize] = useState({ width: 0, height: 0 });

  // Gallery Mode State
  const [galleryImages, setGalleryImages] = useState([]); // Array of { file, url, results, detecting }
  const [activeGalleryIndex, setActiveGalleryIndex] = useState(0);

  // Edit Ingredients State
  const [ingredients, setIngredients] = useState([]);
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);

  const extractUniqueIngredients = (newResults) => {
    if (!newResults) return;
    const labels = newResults.map(r => r.label.toLowerCase());
    setIngredients(prev => {
      const current = new Set(prev.map(p => p.toLowerCase()));
      labels.forEach(l => current.add(l));
      return Array.from(current).map(word => word.charAt(0).toUpperCase() + word.slice(1));
    });
  };

  // Start Camera
  const startCamera = async (ignoreObj = { current: false }) => {
    if (galleryImages.length > 0) return; // Don't start if in gallery mode
    
    // Stop any currently running stream to prevent leaks from multiple calls
    stopCamera();
    
    try {
      const mediaStream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment' } // Prefer back camera
      });
      
      // [CRITICAL FIX] Closure-based race condition check
      // If the effect that initiated this call was cleaned up, stop the stream instantly!
      if (ignoreObj.current) {
        mediaStream.getTracks().forEach(track => track.stop());
        return;
      }
      
      streamRef.current = mediaStream;
      setStream(mediaStream);
      if (videoRef.current) {
        videoRef.current.srcObject = mediaStream;
      }
    } catch (err) {
      if (!ignoreObj.current) {
        console.error("Gagal mengakses kamera:", err);
        setErrorMsg("Gagal mengakses kamera. Pastikan izin telah diberikan.");
      }
    }
  };

  // Stop Camera
  const stopCamera = () => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(track => track.stop());
      streamRef.current = null;
    }
    if (stream) {
      stream.getTracks().forEach(track => track.stop());
    }
    if (videoRef.current && videoRef.current.srcObject) {
      const activeStream = videoRef.current.srcObject;
      activeStream.getTracks().forEach(track => track.stop());
      videoRef.current.srcObject = null;
    }
  };

  useEffect(() => {
    const ignoreObj = { current: false };
    startCamera(ignoreObj);
    return () => {
      ignoreObj.current = true;
      stopCamera();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleClose = () => {
    stopCamera();
    onClose();
  };

  // Capture Image from Webcam
  const handleCapture = () => {
    if (!videoRef.current || !canvasRef.current) return;
    
    const video = videoRef.current;
    const canvas = canvasRef.current;
    const context = canvas.getContext('2d');
    
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    setImageSize({ width: video.videoWidth, height: video.videoHeight });
    context.drawImage(video, 0, 0, canvas.width, canvas.height);
    
    canvas.toBlob((blob) => {
      const imageUrl = URL.createObjectURL(blob);
      setCapturedImage(imageUrl);
      stopCamera();
      processDetection(blob, 'camera');
    }, 'image/jpeg', 0.95);
  };

  // Handle Gallery Selection
  const handleGallerySelect = (e) => {
    const files = Array.from(e.target.files);
    if (files.length === 0) return;

    // Turn off camera
    stopCamera();
    setCapturedImage(null);
    setResults(null);
    
    const newImages = files.map(file => ({
      file,
      url: URL.createObjectURL(file),
      results: null,
      detecting: false
    }));

    setGalleryImages(prev => [...prev, ...newImages]);
    if (galleryImages.length === 0) {
      setActiveGalleryIndex(0);
      updateImageSize(newImages[0].url);
    }
  };

  const updateImageSize = (url) => {
    const img = new Image();
    img.onload = () => {
      setImageSize({ width: img.width, height: img.height });
    };
    img.src = url;
  };

  const handleThumbnailClick = (index) => {
    setActiveGalleryIndex(index);
    updateImageSize(galleryImages[index].url);
  };

  // Process AI
  const processDetection = async (blobOrFile, mode = 'camera', index = 0) => {
    if (mode === 'camera') {
      setIsDetecting(true);
      setResults(null);
    } else {
      setGalleryImages(prev => {
        const copy = [...prev];
        copy[index].detecting = true;
        return copy;
      });
    }

    try {
      const detections = await ApiService.detect(blobOrFile);
      
      extractUniqueIngredients(detections);
      
      if (mode === 'camera') {
        setResults(detections);
        setIsSidebarOpen(true);
      } else {
        setGalleryImages(prev => {
          const copy = [...prev];
          copy[index].results = detections;
          copy[index].detecting = false;
          return copy;
        });
      }
    } catch (err) {
      console.error(err);
      if (mode === 'camera') {
        setErrorMsg("Gagal memproses gambar. AI Server mungkin mati.");
      } else {
        alert("Gagal memproses gambar ke AI.");
        setGalleryImages(prev => {
          const copy = [...prev];
          copy[index].detecting = false;
          return copy;
        });
      }
    } finally {
      if (mode === 'camera') setIsDetecting(false);
    }
  };

  const handleProcessGalleryImage = async () => {
    const unProcessed = galleryImages
      .map((img, idx) => (!img.results && !img.detecting ? idx : -1))
      .filter(idx => idx !== -1);
      
    if (unProcessed.length === 0) return;
    
    for (const idx of unProcessed) {
      await processDetection(galleryImages[idx].file, 'gallery', idx);
    }
    
    setIsSidebarOpen(true);
  };

  // Retake / Clear
  const handleRetake = () => {
    setCapturedImage(null);
    setResults(null);
    setErrorMsg('');
    setGalleryImages([]);
    setIngredients([]);
    setIsSidebarOpen(false);
    startCamera();
  };

  // Determine current viewing state
  const isGalleryMode = galleryImages.length > 0;
  const currentImageObj = isGalleryMode ? galleryImages[activeGalleryIndex] : null;
  const currentImageSrc = isGalleryMode ? currentImageObj.url : capturedImage;
  const currentResults = isGalleryMode ? currentImageObj.results : results;
  const currentDetecting = isGalleryMode ? currentImageObj.detecting : isDetecting;

  const renderBoundingBoxes = () => {
    if (!currentResults || imageSize.width === 0) return null;
    return currentResults.map((det, idx) => {
      const [x1, y1, x2, y2] = det.box;
      const left = (x1 / imageSize.width) * 100;
      const top = (y1 / imageSize.height) * 100;
      const width = ((x2 - x1) / imageSize.width) * 100;
      const height = ((y2 - y1) / imageSize.height) * 100;

      return (
        <div 
          key={idx} 
          className="bounding-box"
          style={{
            left: `${left}%`,
            top: `${top}%`,
            width: `${width}%`,
            height: `${height}%`
          }}
        >
          <span className="box-label">
            {det.label} {Math.round(det.confidence * 100)}%
          </span>
        </div>
      );
    });
  };

  return (
    <div className="camera-container">
      <div className={`camera-modal-card ${isGalleryMode ? 'gallery-mode' : ''}`}>
        
        <EditIngredients 
          isOpen={isSidebarOpen} 
          ingredients={ingredients}
          onAdd={(item) => setIngredients(prev => [...new Set([...prev, item])])}
          onRemove={(item) => setIngredients(prev => prev.filter(i => i !== item))}
          onClose={() => setIsSidebarOpen(false)}
        />
        
        {!isSidebarOpen && ingredients.length > 0 && (
          <button className="open-sidebar-btn" onClick={() => setIsSidebarOpen(true)}>
            <ChevronRight size={24} />
          </button>
        )}

        <canvas ref={canvasRef} style={{ display: 'none' }}></canvas>
        <input 
          type="file" 
          ref={fileInputRef} 
          multiple 
          accept="image/*" 
          style={{ display: 'none' }} 
          onChange={handleGallerySelect}
        />

        <header className="camera-header">
          <h2>{isGalleryMode ? 'Gallery Scanner' : 'Smart Scanner'}</h2>
          <button className="icon-btn close-btn" onClick={handleClose}>
            <X size={20} />
          </button>
        </header>

        <main className="camera-view">
          {errorMsg ? (
            <div className="camera-error">
              <p>{errorMsg}</p>
              <button className="retake-btn" onClick={handleRetake}>Coba Lagi</button>
            </div>
          ) : currentImageSrc ? (
            <div 
              className="result-wrapper"
              style={imageSize.width && imageSize.height ? { 
                aspectRatio: `${imageSize.width} / ${imageSize.height}`,
                width: `min(100cqw, 100cqh * (${imageSize.width} / ${imageSize.height}))`,
                height: `min(100cqh, 100cqw * (${imageSize.height} / ${imageSize.width}))`
              } : {}}
            >
              <img src={currentImageSrc} alt="Preview" className="captured-image" />
              {renderBoundingBoxes()}

              {currentDetecting && (
                <div className="scanner-overlay">
                  <div className="scanner-line"></div>
                  <div className="scanner-text">
                    <Loader2 className="spinner" size={24} />
                    <span>Menganalisis bahan...</span>
                  </div>
                </div>
              )}
            </div>
          ) : (
            <div className="video-wrapper">
              <video 
                ref={videoRef} 
                autoPlay 
                playsInline 
                muted 
                className="live-video"
              />
              <div className="reticle">
                <Maximize size={240} strokeWidth={1} className="reticle-icon" />
              </div>
            </div>
          )}
        </main>

        <footer className="camera-footer">
          {isGalleryMode ? (
            <div className="gallery-controls-wrapper">
              {/* Thumbnail Strip */}
              <div className="thumbnail-strip">
                {galleryImages.map((img, idx) => (
                  <button 
                    key={idx}
                    className={`gallery-thumbnail ${activeGalleryIndex === idx ? 'active' : ''}`}
                    onClick={() => handleThumbnailClick(idx)}
                  >
                    <img src={img.url} alt={`Thumb ${idx}`} />
                    {img.results && <CheckCircle size={16} className="thumb-status-icon" />}
                    {img.detecting && <Loader2 size={16} className="thumb-status-icon spinner" />}
                  </button>
                ))}
                <button className="add-more-btn" onClick={() => fileInputRef.current?.click()}>
                  <ImageIcon size={20} />
                </button>
              </div>

              {/* Action Buttons */}
              <div className="result-controls">
                <button className="secondary-btn" onClick={handleRetake} disabled={currentDetecting}>
                  <Camera size={20} />
                  <span>Kamera</span>
                </button>
                <button 
                  className="primary-btn" 
                  disabled={currentDetecting}
                  onClick={() => {
                    const hasUnprocessed = galleryImages.some(img => !img.results);
                    if (hasUnprocessed) {
                      handleProcessGalleryImage();
                    } else {
                      alert(`Membawa bahan final ke resep:\n- ${ingredients.join('\n- ')}`);
                    }
                  }}
                >
                  {galleryImages.some(img => !img.results) ? (
                    <>
                      <Sparkles size={20} />
                      <span>Pindai Semua</span>
                    </>
                  ) : (
                    <>
                      <span>Lanjut Resep</span>
                    </>
                  )}
                </button>
              </div>
            </div>
          ) : capturedImage ? (
            <div className="result-controls">
              <button className="secondary-btn" onClick={handleRetake} disabled={isDetecting}>
                <RefreshCw size={20} />
                <span>Foto Ulang</span>
              </button>
              <button 
                className="primary-btn" 
                disabled={isDetecting || !results}
                onClick={() => {
                  alert(`Membawa bahan final ke resep:\n- ${ingredients.join('\n- ')}`);
                }}
              >
                <span>Lihat Resep</span>
              </button>
            </div>
          ) : (
            <div className="capture-controls-row">
              <button className="gallery-btn" onClick={() => fileInputRef.current?.click()}>
                <ImageIcon size={28} />
              </button>
              <div className="capture-controls">
                <button className="capture-ring" onClick={handleCapture}>
                  <div className="capture-btn">
                    <Camera size={32} />
                  </div>
                </button>
                <p className="hint-text">Arahkan ke bahan makanan</p>
              </div>
              <div className="spacer-btn"></div>
            </div>
          )}
        </footer>
      </div>
    </div>
  );
}
