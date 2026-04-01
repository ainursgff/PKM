/**
 * Konfigurasi server — mirror dari Flutter config.dart
 *
 * Di development, semua request /api/* di-proxy oleh Vite ke backend.
 * Jadi kita cukup pakai path relatif, tidak perlu hardcode IP.
 */

const ServerConfig = {
  /** Port backend Express */
  port: 3000,

  /**
   * Base URL untuk API calls.
   * Kosong ('') karena Vite proxy handle /api/* → backend.
   * Di production, ganti dengan URL backend production.
   */
  get base() {
    return '';
  },

  /** Prefix untuk semua API endpoint */
  get apiBase() {
    return `${this.base}/api`;
  },

  /** Base URL untuk gambar makanan */
  get imageBase() {
    return `${this.base}/makanan/gambar/`;
  },

  /** Base URL untuk video makanan */
  get videoBase() {
    return `${this.base}/makanan/video/`;
  },
};

export default ServerConfig;
