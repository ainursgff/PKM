import { useState, useEffect } from 'react';
import {
  Search, ChefHat, TrendingUp, Clock, Users, Star,
  Play, ArrowRight, Flame, Sparkles, Menu, X,
  Home, Camera, Heart, BookOpen, UtensilsCrossed, LogIn
} from 'lucide-react';
import './main.css';

import ServerConfig from '../config';
import ApiService from '../services/api_service';

export default function MainPage() {
  const [makanan, setMakanan] = useState([]);
  const [trending, setTrending] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [hoveredCard, setHoveredCard] = useState(null);

  useEffect(() => {
    loadMakanan();
  }, []);

  async function loadMakanan() {
    try {
      const data = await ApiService.getMakanan();
      setMakanan(data);
      setTrending(data.filter(m => m.url_video && m.url_video.length > 0));
      setIsLoading(false);
    } catch (e) {
      console.error('Error loading makanan:', e);
      setIsLoading(false);
    }
  }

  const filteredMakanan = searchQuery.trim()
    ? makanan.filter(m =>
        m.nama_makanan?.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : makanan;

  return (
    <div className="layout">
      {/* ========== SIDEBAR ========== */}
      <aside className={`sidebar ${sidebarOpen ? 'open' : 'collapsed'}`}>
        <div className="sidebar-header">
          <div className="sidebar-logo">
            <div className="logo-icon">
              <UtensilsCrossed size={20} />
            </div>
            {sidebarOpen && <span className="logo-text">SmartCooks</span>}
          </div>
          <button
            className="sidebar-toggle"
            onClick={() => setSidebarOpen(!sidebarOpen)}
          >
            {sidebarOpen ? <X size={18} /> : <Menu size={18} />}
          </button>
        </div>

        <nav className="sidebar-nav">
          <a href="#" className="nav-item active">
            <Home size={20} />
            {sidebarOpen && <span>Beranda</span>}
          </a>
          <a href="#" className="nav-item">
            <Search size={20} />
            {sidebarOpen && <span>Cari Resep</span>}
          </a>
          <a href="#" className="nav-item">
            <BookOpen size={20} />
            {sidebarOpen && <span>Koleksi Saya</span>}
          </a>
          <a href="#" className="nav-item">
            <Heart size={20} />
            {sidebarOpen && <span>Favorit</span>}
          </a>
          <a href="#" className="nav-item">
            <Camera size={20} />
            {sidebarOpen && <span>Scan Bahan</span>}
          </a>
        </nav>

        {sidebarOpen && (
          <div className="sidebar-footer">
            <p className="sidebar-footer-text">
              Scan bahan makanan dengan AI untuk mendapatkan resep otomatis.
            </p>
          </div>
        )}
      </aside>

      {/* ========== MAIN CONTENT ========== */}
      <main className="main-content">
        {/* Top Bar */}
        <header className="topbar">
          <div className="topbar-left">
            <button
              className="mobile-menu-btn"
              onClick={() => setSidebarOpen(!sidebarOpen)}
            >
              <Menu size={22} />
            </button>
          </div>
          <div className="topbar-right">
            <button className="btn-login">
              <LogIn size={16} />
              <span>Masuk</span>
            </button>
            <button className="btn-primary">
              <ChefHat size={16} />
              <span>Tulis Resep</span>
            </button>
          </div>
        </header>

        <div className="content-scroll">
          {/* Hero Section */}
          <section className="hero-section">
            <div className="hero-brand">
              <div className="hero-logo-icon">
                <UtensilsCrossed size={28} />
              </div>
              <h1 className="hero-title">SmartCooks</h1>
              <p className="hero-subtitle">
                Temukan resep terbaik dari bahan yang kamu punya
              </p>
            </div>

            {/* Search Bar */}
            <div className="search-container">
              <div className="search-box">
                <Search size={20} className="search-icon" />
                <input
                  type="text"
                  placeholder="Cari resep, bahan, atau makanan..."
                  value={searchQuery}
                  onChange={e => setSearchQuery(e.target.value)}
                  className="search-input"
                />
                <button className="search-btn">Cari</button>
              </div>
              <div className="search-tags">
                {['Ayam Goreng', 'Rendang', 'Nasi Goreng', 'Sayur Asem'].map(tag => (
                  <button
                    key={tag}
                    className="search-tag"
                    onClick={() => setSearchQuery(tag)}
                  >
                    {tag}
                  </button>
                ))}
              </div>
            </div>
          </section>

          {/* Banner */}
          <section className="banner-section">
            <div className="banner-card">
              <img
                src="/hero-banner.png"
                alt="SmartCooks Banner"
                className="banner-image"
              />
              <div className="banner-overlay">
                <div className="banner-badge">
                  <Sparkles size={14} />
                  <span>AI Powered</span>
                </div>
                <h2 className="banner-title">
                  Masak Lebih Pintar<br />dengan SmartCooks
                </h2>
                <p className="banner-desc">
                  Scan bahan makanan → AI deteksi otomatis → Resep instan
                </p>
                <button className="banner-btn">
                  <Camera size={16} />
                  <span>Coba Scan Bahan</span>
                  <ArrowRight size={16} />
                </button>
              </div>
            </div>
          </section>

          {/* Trending Section */}
          <section className="section">
            <div className="section-header">
              <div className="section-title-group">
                <TrendingUp size={20} className="section-icon" />
                <h2 className="section-title">Trending</h2>
              </div>
              <button className="see-all-btn">
                Lihat Semua <ArrowRight size={14} />
              </button>
            </div>

            <div className="trending-scroll">
              {isLoading ? (
                <div className="trending-skeleton-row">
                  {[1,2,3,4,5].map(i => (
                    <div key={i} className="trending-skeleton" />
                  ))}
                </div>
              ) : trending.length > 0 ? (
                trending.map((item, index) => (
                  <div key={item.id || index} className="trending-item">
                    <div className="trending-ring">
                      <img
                        src={`${ServerConfig.imageBase}${item.foto_utama}`}
                        alt={item.nama_makanan}
                        className="trending-img"
                        onError={e => { e.target.src = '/hero-banner.png'; }}
                      />
                      <div className="trending-play">
                        <Play size={16} fill="white" />
                      </div>
                    </div>
                    <span className="trending-name">
                      {item.nama_makanan}
                    </span>
                  </div>
                ))
              ) : (
                <p className="empty-text">Belum ada trending saat ini</p>
              )}
            </div>
          </section>

          {/* Stats Bar */}
          <section className="stats-bar">
            <div className="stat-item">
              <Flame size={18} className="stat-icon" />
              <span className="stat-value">{makanan.length}</span>
              <span className="stat-label">Resep</span>
            </div>
            <div className="stat-divider" />
            <div className="stat-item">
              <Users size={18} className="stat-icon" />
              <span className="stat-value">1.2K</span>
              <span className="stat-label">Pengguna</span>
            </div>
            <div className="stat-divider" />
            <div className="stat-item">
              <Star size={18} className="stat-icon" />
              <span className="stat-value">4.8</span>
              <span className="stat-label">Rating</span>
            </div>
            <div className="stat-divider" />
            <div className="stat-item">
              <Clock size={18} className="stat-icon" />
              <span className="stat-value">~30m</span>
              <span className="stat-label">Rata-rata</span>
            </div>
          </section>

          {/* Recipe Grid */}
          <section className="section">
            <div className="section-header">
              <div className="section-title-group">
                <UtensilsCrossed size={20} className="section-icon" />
                <h2 className="section-title">Semua Resep</h2>
              </div>
              <span className="recipe-count">
                {filteredMakanan.length} resep ditemukan
              </span>
            </div>

            {isLoading ? (
              <div className="recipe-grid">
                {[1,2,3,4,5,6].map(i => (
                  <div key={i} className="recipe-card-skeleton" />
                ))}
              </div>
            ) : (
              <div className="recipe-grid">
                {filteredMakanan.map((item, index) => (
                  <article
                    key={item.id || index}
                    className={`recipe-card ${hoveredCard === index ? 'hovered' : ''}`}
                    onMouseEnter={() => setHoveredCard(index)}
                    onMouseLeave={() => setHoveredCard(null)}
                  >
                    <div className="recipe-card-image-wrap">
                      <img
                        src={`${ServerConfig.imageBase}${item.foto_utama}`}
                        alt={item.nama_makanan}
                        className="recipe-card-image"
                        onError={e => { e.target.src = '/hero-banner.png'; }}
                      />
                      <div className="recipe-card-overlay">
                        <button className="recipe-card-fav">
                          <Heart size={16} />
                        </button>
                      </div>
                      {item.url_video && (
                        <div className="recipe-card-video-badge">
                          <Play size={12} fill="white" />
                          <span>Video</span>
                        </div>
                      )}
                    </div>

                    <div className="recipe-card-body">
                      <h3 className="recipe-card-name">
                        {item.nama_makanan}
                      </h3>
                      <div className="recipe-card-meta">
                        <span className="recipe-card-tag">
                          <Clock size={12} />
                          30 menit
                        </span>
                        <span className="recipe-card-tag">
                          <Star size={12} fill="var(--orange-400)" />
                          4.8
                        </span>
                      </div>
                    </div>
                  </article>
                ))}
              </div>
            )}

            {filteredMakanan.length === 0 && !isLoading && (
              <div className="empty-state">
                <Search size={48} className="empty-icon" />
                <h3>Tidak ada resep ditemukan</h3>
                <p>Coba cari dengan kata kunci lain</p>
              </div>
            )}
          </section>
        </div>
      </main>
    </div>
  );
}
