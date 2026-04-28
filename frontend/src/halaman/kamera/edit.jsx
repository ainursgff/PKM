import { useState } from 'react';
import { X, Plus, Edit3 } from 'lucide-react';
import './edit.css';

export default function EditIngredients({ 
  isOpen, 
  ingredients, 
  onRemove, 
  onAdd, 
  onClose 
}) {
  const [inputValue, setInputValue] = useState('');

  const handleAdd = (e) => {
    e.preventDefault();
    if (inputValue.trim()) {
      onAdd(inputValue.trim());
      setInputValue('');
    }
  };

  return (
    <aside className={`ingredients-sidebar ${isOpen ? 'open' : ''}`}>
      <div className="sidebar-header-edit">
        <div className="header-title-edit">
          <Edit3 size={18} className="edit-icon" />
          <h3>Daftar Bahan</h3>
        </div>
        <button className="close-sidebar-btn" onClick={onClose}>
          <X size={18} />
        </button>
      </div>

      <div className="sidebar-content">
        <p className="sidebar-desc">
          Verifikasi hasil deteksi AI. Anda dapat menambah bahan manual atau menghapus yang keliru.
        </p>

        <form className="add-ingredient-form" onSubmit={handleAdd}>
          <input 
            type="text" 
            placeholder="Tambah manual..." 
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            className="add-input"
          />
          <button type="submit" className="add-submit-btn" disabled={!inputValue.trim()}>
            <Plus size={18} />
          </button>
        </form>

        <div className="ingredients-list">
          {ingredients.length === 0 ? (
            <div className="empty-ingredients">
              <p>Belum ada bahan terdeteksi.</p>
            </div>
          ) : (
            ingredients.map((item, index) => (
              <div key={index} className="ingredient-chip">
                <span className="chip-label">{item}</span>
                <button 
                  className="chip-remove-btn" 
                  onClick={() => onRemove(item)}
                  title="Hapus bahan"
                >
                  <X size={14} />
                </button>
              </div>
            ))
          )}
        </div>
      </div>
    </aside>
  );
}
