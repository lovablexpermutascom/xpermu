import React, { useState, useEffect } from 'react';
import { supabase, DatabaseCategory } from '../../../lib/supabase';
import { Loader2, Plus, Trash2, Edit } from 'lucide-react';
import { useForm } from 'react-hook-form';
import { Modal } from '../../../components/ui/Modal';

type CategoryFormData = {
  name: string;
  description: string;
  icon: string;
  color: string;
  is_active: boolean;
};

export function AdminCategories() {
  const [categories, setCategories] = useState<DatabaseCategory[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingCategory, setEditingCategory] = useState<DatabaseCategory | null>(null);

  const { register, handleSubmit, reset, setValue } = useForm<CategoryFormData>();

  useEffect(() => {
    fetchCategories();
  }, []);

  const fetchCategories = async () => {
    setIsLoading(true);
    const { data, error } = await supabase.from('categories').select('*').order('name');
    if (error) console.error(error);
    else setCategories(data || []);
    setIsLoading(false);
  };

  const openModal = (category: DatabaseCategory | null = null) => {
    setEditingCategory(category);
    if (category) {
      reset(category);
    } else {
      reset({ name: '', description: '', icon: '', color: '#0066cc', is_active: true });
    }
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setEditingCategory(null);
    reset();
  };

  const onSubmit = async (data: CategoryFormData) => {
    const { error } = editingCategory
      ? await supabase.from('categories').update(data).eq('id', editingCategory.id)
      : await supabase.from('categories').insert(data);
    
    if (error) {
      alert(error.message);
    } else {
      closeModal();
      fetchCategories();
    }
  };
  
  const handleDelete = async (id: string) => {
    if (window.confirm('Tem a certeza que quer apagar esta categoria?')) {
      const { error } = await supabase.from('categories').delete().eq('id', id);
      if (error) alert(error.message);
      else fetchCategories();
    }
  };

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Gestão de Categorias</h1>
        <button onClick={() => openModal()} className="flex items-center bg-primary-600 text-white px-4 py-2 rounded-lg hover:bg-primary-700">
          <Plus className="w-5 h-5 mr-2" />
          Nova Categoria
        </button>
      </div>
      <div className="bg-white shadow-md rounded-lg overflow-x-auto">
        <table className="w-full table-auto">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Nome</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Ativa</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Ações</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {isLoading ? (
              <tr><td colSpan={3} className="text-center py-8"><Loader2 className="w-8 h-8 text-primary-500 animate-spin mx-auto" /></td></tr>
            ) : (
              categories.map(cat => (
                <tr key={cat.id}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 flex items-center">
                    <span className="w-4 h-4 rounded-full mr-3" style={{ backgroundColor: cat.color || '#ccc' }}></span>
                    {cat.name}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{cat.is_active ? 'Sim' : 'Não'}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium space-x-4">
                    <button onClick={() => openModal(cat)} className="text-primary-600 hover:text-primary-900"><Edit className="w-5 h-5" /></button>
                    <button onClick={() => handleDelete(cat.id)} className="text-red-600 hover:text-red-900"><Trash2 className="w-5 h-5" /></button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <Modal isOpen={isModalOpen} onClose={closeModal} title={editingCategory ? 'Editar Categoria' : 'Nova Categoria'}>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div>
            <label className="block text-sm font-medium">Nome</label>
            <input {...register('name', { required: true })} className="w-full mt-1 p-2 border rounded" />
          </div>
          <div>
            <label className="block text-sm font-medium">Descrição</label>
            <textarea {...register('description')} className="w-full mt-1 p-2 border rounded" />
          </div>
          <div className="flex items-center space-x-4">
            <div>
              <label className="block text-sm font-medium">Cor</label>
              <input type="color" {...register('color')} className="w-12 h-12 mt-1 p-1 border rounded" />
            </div>
            <div className="flex items-center pt-6">
              <input type="checkbox" {...register('is_active')} id="is_active" className="h-4 w-4 rounded" />
              <label htmlFor="is_active" className="ml-2 block text-sm">Ativa</label>
            </div>
          </div>
          <div className="flex justify-end space-x-2 pt-4">
            <button type="button" onClick={closeModal} className="px-4 py-2 bg-gray-200 rounded-lg">Cancelar</button>
            <button type="submit" className="px-4 py-2 bg-primary-600 text-white rounded-lg">Guardar</button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
