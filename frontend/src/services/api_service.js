/**
 * API Service — mirror dari Flutter api_service.dart
 *
 * Semua endpoint backend terpusat di sini.
 * Menggunakan ServerConfig untuk base URL.
 */

import ServerConfig from '../config';

const ApiService = {
  // ================================
  // GET MAKANAN
  // ================================
  async getMakanan() {
    const res = await fetch(`${ServerConfig.apiBase}/makanan`);

    if (!res.ok) throw new Error('Gagal mengambil data makanan');

    return res.json();
  },

  // ================================
  // GET DETAIL MAKANAN
  // ================================
  async getMakananById(id) {
    const res = await fetch(`${ServerConfig.apiBase}/makanan/${id}`);

    if (!res.ok) throw new Error('Gagal mengambil detail makanan');

    return res.json();
  },

  // ================================
  // LOGIN
  // ================================
  async login(email, password) {
    const res = await fetch(`${ServerConfig.apiBase}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });

    if (!res.ok) return null;

    return res.json();
  },

  // ================================
  // REGISTER
  // ================================
  async register(nama, email, password) {
    const res = await fetch(`${ServerConfig.apiBase}/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ nama, email, password }),
    });

    if (!res.ok) return null;

    return res.json();
  },
};

export default ApiService;
