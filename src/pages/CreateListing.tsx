import React, { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import * as yup from 'yup';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { supabase, DatabaseCategory } from '../lib/supabase';
import { listingSchema } from '../lib/validations';
import { motion } from 'framer-motion';
import { Loader2, CheckCircle, AlertCircle, Upload, X, Image as ImageIcon } from 'lucide-react';
import { v4 as uuidv4 } from 'uuid';

type ListingFormData = yup.InferType<typeof listingSchema>;

export function CreateListing() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [categories, setCategories] = useState<DatabaseCategory[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [formSuccess, setFormSuccess] = useState(false);
  const [imageFiles, setImageFiles] = useState<File[]>([]);
  const [imagePreviews, setImagePreviews] = useState<string[]>([]);

  const { register, handleSubmit, formState: { errors } } = useForm<ListingFormData>({
    resolver: yupResolver(listingSchema),
  });

  useEffect(() => {
    fetchCategories();
  }, []);

  const fetchCategories = async () => {
    const { data, error } = await supabase
      .from('categories')
      .select('*')
      .eq('is_active', true)
      .order('name');
    if (error) {
      console.error('Error fetching categories:', error);
    } else {
      setCategories(data);
    }
  };

  const handleImageChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      const files = Array.from(e.target.files);
      const newFiles = [...imageFiles, ...files].slice(0, 5); // Limit to 5 images
      setImageFiles(newFiles);

      const newPreviews = newFiles.map(file => URL.createObjectURL(file));
      setImagePreviews(newPreviews);
    }
  };

  const removeImage = (index: number) => {
    const newFiles = [...imageFiles];
    newFiles.splice(index, 1);
    setImageFiles(newFiles);

    const newPreviews = [...imagePreviews];
    newPreviews.splice(index, 1);
    setImagePreviews(newPreviews);
  };

  const uploadImages = async (): Promise<string[]> => {
    if (!user || imageFiles.length === 0) return [];

    const uploadPromises = imageFiles.map(file => {
      const fileName = `${uuidv4()}-${file.name}`;
      const filePath = `${user.id}/${fileName}`;
      return supabase.storage.from('listings-images').upload(filePath, file);
    });

    const results = await Promise.all(uploadPromises);
    const urls: string[] = [];

    for (const result of results) {
      if (result.error) {
        console.error('Image upload error:', result.error);
        throw new Error('Falha no upload de uma ou mais imagens.');
      }
      const { data: { publicUrl } } = supabase.storage.from('listings-images').getPublicUrl(result.data.path);
      urls.push(publicUrl);
    }

    return urls;
  };

  const onSubmit = async (data: ListingFormData) => {
    if (!user) {
      setFormError('Precisa estar autenticado para criar um anúncio.');
      return;
    }
    if (imageFiles.length === 0) {
      setFormError('Por favor, adicione pelo menos uma imagem.');
      return;
    }

    setIsLoading(true);
    setFormError(null);

    try {
      const imageUrls = await uploadImages();

      const { error } = await supabase.from('listings').insert({
        ...data,
        user_id: user.id,
        status: 'active',
        images: imageUrls,
      });

      if (error) {
        throw error;
      }

      setFormSuccess(true);
      setTimeout(() => {
        navigate('/my-listings');
      }, 2000);

    } catch (error: any) {
      console.error('Error creating listing:', error);
      setFormError(error.message || 'Ocorreu um erro ao criar o anúncio.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 py-12">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <div className="bg-white shadow-xl rounded-2xl p-8">
            <h1 className="text-3xl font-bold text-gray-900 mb-2">Criar Novo Anúncio</h1>
            <p className="text-gray-600 mb-8">Partilhe o seu produto ou serviço com a comunidade XPermutas.</p>

            <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
              {/* Form fields... */}
              <div>
                <label htmlFor="title" className="block text-sm font-medium text-gray-700 mb-1">Título do Anúncio</label>
                <input type="text" id="title" {...register('title')} className={`w-full p-3 border rounded-lg ${errors.title ? 'border-red-500' : 'border-gray-300'}`} />
                {errors.title && <p className="text-red-500 text-sm mt-1">{errors.title.message}</p>}
              </div>

              <div>
                <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-1">Descrição Detalhada</label>
                <textarea id="description" {...register('description')} rows={5} className={`w-full p-3 border rounded-lg ${errors.description ? 'border-red-500' : 'border-gray-300'}`}></textarea>
                {errors.description && <p className="text-red-500 text-sm mt-1">{errors.description.message}</p>}
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label htmlFor="price" className="block text-sm font-medium text-gray-700 mb-1">Preço (em X$)</label>
                  <input type="number" id="price" step="0.01" {...register('price')} className={`w-full p-3 border rounded-lg ${errors.price ? 'border-red-500' : 'border-gray-300'}`} />
                  {errors.price && <p className="text-red-500 text-sm mt-1">{errors.price.message}</p>}
                </div>
                <div>
                  <label htmlFor="category_id" className="block text-sm font-medium text-gray-700 mb-1">Categoria</label>
                  <select id="category_id" {...register('category_id')} className={`w-full p-3 border rounded-lg bg-white ${errors.category_id ? 'border-red-500' : 'border-gray-300'}`}>
                    <option value="">Selecione uma categoria</option>
                    {categories.map(cat => <option key={cat.id} value={cat.id}>{cat.name}</option>)}
                  </select>
                  {errors.category_id && <p className="text-red-500 text-sm mt-1">{errors.category_id.message}</p>}
                </div>
              </div>

              <div>
                <label htmlFor="location" className="block text-sm font-medium text-gray-700 mb-1">Localização</label>
                <input type="text" id="location" {...register('location')} className={`w-full p-3 border rounded-lg ${errors.location ? 'border-red-500' : 'border-gray-300'}`} placeholder="Ex: Lisboa, Portugal" />
                {errors.location && <p className="text-red-500 text-sm mt-1">{errors.location.message}</p>}
              </div>

              {/* Image Upload */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Imagens (até 5)</label>
                <div className="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md">
                  <div className="space-y-1 text-center">
                    <Upload className="mx-auto h-12 w-12 text-gray-400" />
                    <div className="flex text-sm text-gray-600">
                      <label htmlFor="file-upload" className="relative cursor-pointer bg-white rounded-md font-medium text-primary-600 hover:text-primary-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-primary-500">
                        <span>Carregar ficheiros</span>
                        <input id="file-upload" name="file-upload" type="file" className="sr-only" multiple accept="image/*" onChange={handleImageChange} disabled={imageFiles.length >= 5} />
                      </label>
                      <p className="pl-1">ou arraste e solte</p>
                    </div>
                    <p className="text-xs text-gray-500">PNG, JPG, GIF até 10MB</p>
                  </div>
                </div>
                {imagePreviews.length > 0 && (
                  <div className="mt-4 grid grid-cols-3 sm:grid-cols-5 gap-4">
                    {imagePreviews.map((preview, index) => (
                      <div key={index} className="relative group">
                        <img src={preview} alt={`Preview ${index}`} className="h-24 w-full object-cover rounded-md" />
                        <button
                          type="button"
                          onClick={() => removeImage(index)}
                          className="absolute -top-2 -right-2 bg-red-500 text-white rounded-full p-1 opacity-0 group-hover:opacity-100 transition-opacity"
                        >
                          <X className="w-3 h-3" />
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {formError && (
                <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg flex items-center space-x-2">
                  <AlertCircle className="w-5 h-5" />
                  <span>{formError}</span>
                </div>
              )}

              {formSuccess && (
                <div className="bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded-lg flex items-center space-x-2">
                  <CheckCircle className="w-5 h-5" />
                  <span>Anúncio criado com sucesso! A redirecionar...</span>
                </div>
              )}

              <div className="pt-4">
                <button
                  type="submit"
                  disabled={isLoading || formSuccess}
                  className="w-full flex justify-center py-3 px-4 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 disabled:opacity-50"
                >
                  {isLoading ? (
                    <Loader2 className="w-5 h-5 animate-spin" />
                  ) : (
                    'Publicar Anúncio'
                  )}
                </button>
              </div>
            </form>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
