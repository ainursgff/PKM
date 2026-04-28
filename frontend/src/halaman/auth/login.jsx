import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Utensils, Mail, Lock } from 'lucide-react';
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

  const createRipple = (event) => {
    const button = event.currentTarget;
    if (button.disabled) return;
    
    const circle = document.createElement("span");
    const diameter = Math.max(button.clientWidth, button.clientHeight);
    const radius = diameter / 2;

    const rect = button.getBoundingClientRect();
    circle.style.width = circle.style.height = `${diameter}px`;
    circle.style.left = `${event.clientX - rect.left - radius}px`;
    circle.style.top = `${event.clientY - rect.top - radius}px`;
    circle.classList.add("material-ripple-effect");

    const existingRipple = button.getElementsByClassName("material-ripple-effect")[0];
    if (existingRipple) {
      existingRipple.remove();
    }

    button.appendChild(circle);
    setTimeout(() => circle.remove(), 600);
  };

  return (
    <div className="login-container">
      {/* App Bar (Mirroring Flutter) */}
      <header className="login-appbar">
        <button className="back-button" onClick={() => navigate('/')}>
          <ArrowLeft size={24} />
        </button>
        <h1>Login</h1>
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

            <button 
              type="submit" 
              className="login-button material-btn" 
              disabled={loading}
              onMouseDown={createRipple}
            >
              {loading ? (
                <div className="material-spinner">
                  <svg className="circular" viewBox="25 25 50 50">
                    <circle className="path" cx="50" cy="50" r="20" fill="none" strokeWidth="4" strokeMiterlimit="10" />
                  </svg>
                </div>
              ) : 'LOGIN'}
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
