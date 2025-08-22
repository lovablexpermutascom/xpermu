import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { supabase, DatabaseUser } from '../../../lib/supabase';
import { Modal } from '../../../components/ui/Modal';
import { Loader2 } from 'lucide-react';

interface UserEditModalProps {
  isOpen: boolean;
  onClose: () => void;
  user: DatabaseUser;
  onUserUpdate: (user: DatabaseUser) => void;
}

type FormData = {
  name: string;
  status: 'pending' | 'approved' | 'rejected' | 'suspended';
  role: 'user' | 'admin';
  balance_xs: number;
  balance_bonus: number;
  debt_xs: number;
};

export function UserEditModal({ isOpen, onClose, user, onUserUpdate }: UserEditModalProps) {
  const { register, handleSubmit, formState: { errors } } = useForm<FormData>({
    defaultValues: {
      name: user.name,
      status: user.status,
      role: user.role,
      balance_xs: user.balance_xs,
      balance_bonus: user.balance_bonus,
      debt_xs: user.debt_xs,
    },
  });
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const onSubmit = async (data: FormData) => {
    setIsLoading(true);
    setError(null);
    try {
      // Check if status is changing to 'approved'
      const statusChangedToApproved = data.status === 'approved' && user.status !== 'approved';

      const { data: updatedUser, error } = await supabase
        .from('users')
        .update({ 
          ...data,
          balance_xs: Number(data.balance_xs),
          balance_bonus: Number(data.balance_bonus),
          debt_xs: Number(data.debt_xs),
         })
        .eq('id', user.id)
        .select()
        .single();

      if (error) throw error;
      
      // If status changed to approved, call the bonus function
      if (statusChangedToApproved) {
        const { error: rpcError } = await supabase.rpc('grant_referral_bonus', { approved_user_id: user.id });
        if (rpcError) {
          // Log the error but don't block the UI update
          console.error('Error granting referral bonus:', rpcError);
        }
      }

      onUserUpdate(updatedUser);
    } catch (err: any) {
      setError(err.message || 'Ocorreu um erro ao atualizar o utilizador.');
    } finally {
      setIsLoading(false);
    }
  };
  
  const statusOptions: DatabaseUser['status'][] = ['pending', 'approved', 'rejected', 'suspended'];
  const roleOptions: DatabaseUser['role'][] = ['user', 'admin'];

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={`Editar Utilizador: ${user.name}`}
      footer={
        <div className="space-x-2">
          <button onClick={onClose} className="px-4 py-2 bg-gray-200 rounded-lg">Cancelar</button>
          <button onClick={handleSubmit(onSubmit)} className="px-4 py-2 bg-primary-600 text-white rounded-lg" disabled={isLoading}>
            {isLoading ? <Loader2 className="w-5 h-5 animate-spin" /> : 'Guardar Alterações'}
          </button>
        </div>
      }
    >
      <form className="space-y-4">
        {error && <p className="text-red-500">{error}</p>}
        <div>
          <label className="block text-sm font-medium text-gray-700">Nome</label>
          <input {...register('name', { required: true })} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3" />
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700">Status</label>
            <select {...register('status')} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 bg-white">
              {statusOptions.map(s => <option key={s} value={s}>{s}</option>)}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700">Role</label>
            <select {...register('role')} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 bg-white">
              {roleOptions.map(r => <option key={r} value={r}>{r}</option>)}
            </select>
          </div>
        </div>
        <div className="grid grid-cols-3 gap-4">
            <div>
                <label className="block text-sm font-medium text-gray-700">Saldo X$</label>
                <input type="number" step="0.01" {...register('balance_xs')} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3" />
            </div>
            <div>
                <label className="block text-sm font-medium text-gray-700">Bónus €</label>
                <input type="number" step="0.01" {...register('balance_bonus')} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3" />
            </div>
            <div>
                <label className="block text-sm font-medium text-gray-700">Dívida X$</label>
                <input type="number" step="0.01" {...register('debt_xs')} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3" />
            </div>
        </div>
      </form>
    </Modal>
  );
}
