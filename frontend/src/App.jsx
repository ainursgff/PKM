import { BrowserRouter, Routes, Route } from 'react-router-dom';
import MainPage from './halaman/main';
import LoginPage from './halaman/auth/login';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<MainPage />} />
        <Route path="/login" element={<LoginPage />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
