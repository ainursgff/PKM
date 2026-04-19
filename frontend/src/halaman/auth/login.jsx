import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Utensils, Mail, Lock, Loader2 } from 'lucide-react';
import ApiService from '../../services/api_service';
import './login.css';

export default function LoginPage() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [flashMessage, setFlashMessage] = useState(null);

  const showFlash = (type, message) => {
    setFlashMessage({ type, message });
    setTimeout(() => setFlashMessage(null), 3000);
  };

  const handleLogin = async (e) => {
    e.preventDefault();

    if (!email || !password) {
      showFlash('warning', 'Email dan password wajib diisi');
      return;
    }

    setLoading(true);

    try {
      const res = await ApiService.login(email.trim(), password.trim());

      setLoading(false);

      if (res) {
        showFlash('success', 'Login berhasil');
        setTimeout(() => {
          navigate('/');
        }, 1000);
      } else {
        showFlash('error', 'Email atau password salah');
      }
    } catch (error) {
      setLoading(false);
      showFlash('error', 'Terjadi kesalahan server');
    }
  };

  return (
    <div className="login-container">
      {/* App Bar (Mirroring Flutter) */}
      <header className="login-appbar">
        <button className="back-button" onClick={() => navigate('/')}>
          <ArrowLeft size={24} />
        </button>
        <h1>Login</h1>
        <div style={{ width: 48 }}></div> {/* Placeholder to center title */}
      </header>

      {/* Flash Message Toast */}
      {flashMessage && (
        <div className={`flash-message flash-${flashMessage.type}`}>
          {flashMessage.message}
        </div>
      )}

      {/* Body Content */}
      <main className="login-body">
        <div className="login-card">
          <div className="icon-wrapper">
            <Utensils size={60} className="main-icon" />
          </div>
          
          <h2 className="title">SmartCooks</h2>

          <form onSubmit={handleLogin} className="login-form">
            <div className={`input-group ${email ? 'has-value' : ''}`}>
              <span className="input-icon">
                <Mail size={20} />
              </span>
              <div className="input-wrapper">
                <input
                  id="email-input"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  disabled={loading}
                />
                <label className="floating-label" htmlFor="email-input">Email</label>
              </div>
            </div>

            <div className={`input-group ${password ? 'has-value' : ''}`}>
              <span className="input-icon">
                <Lock size={20} />
              </span>
              <div className="input-wrapper">
                <input
                  id="password-input"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  disabled={loading}
                />
                <label className="floating-label" htmlFor="password-input">Password</label>
              </div>
            </div>

            <button type="submit" className="login-button ripple" disabled={loading}>
              {loading ? <Loader2 size={22} className="spinner" /> : 'LOGIN'}
            </button>
          </form>

          <div className="register-link">
            <span>Belum punya akun?</span>
            <button onClick={() => navigate('/register')} className="btn-text">
              Register
            </button>
          </div>
        </div>
      </main>
    </div>
  );
}
