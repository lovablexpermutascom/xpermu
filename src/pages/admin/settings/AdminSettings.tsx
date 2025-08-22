import React, { useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { supabase } from '../../../lib/supabase';
import { Loader2 } from 'lucide-react';

type SettingsData = {
  referral_bonus: { referrer: number; referee: number };
  transaction_commission_rate: { rate: number };
};

export function AdminSettings() {
  const { register, handleSubmit, setValue, formState: { isSubmitting, isDirty } } = useForm<SettingsData>();

  useEffect(() => {
    const fetchSettings = async () => {
      const { data, error } = await supabase.from('system_settings').select('*');
      if (error) {
        console.error('Error fetching settings:', error);
        alert('Não foi possível carregar as configurações.');
        return;
      }
      data.forEach(setting => {
        if (setting.key in { referral_bonus: '', transaction_commission_rate: '' }) {
          setValue(setting.key as keyof SettingsData, setting.value);
        }
      });
    };
    fetchSettings();
  }, [setValue]);

  const onSubmit = async (data: SettingsData) => {
    try {
      const updates = Object.entries(data).map(([key, value]) => 
        supabase.from('system_settings').update({ value }).eq('key', key)
      );
      await Promise.all(updates);
      alert('Configurações guardadas com sucesso!');
    } catch (error: any) {
      alert('Erro ao guardar configurações: ' + error.message);
    }
  };

  return (
    <div>
      <h1 className="text-2xl font-bold text-gray-800 mb-6">Configurações do Sistema</h1>
      <form onSubmit={handleSubmit(onSubmit)} className="bg-white p-8 rounded-lg shadow-md max-w-2xl space-y-8">
        <div>
          <h2 className="text-xl font-semibold">Programa de Indicação</h2>
          <p className="text-sm text-gray-500 mb-4">Defina os valores de bónus em Euros (€).</p>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium">Bónus para quem indica</label>
              <input type="number" step="0.01" {...register('referral_bonus.referrer', { valueAsNumber: true })} className="w-full mt-1 p-2 border rounded" />
            </div>
            <div>
              <label className="block text-sm font-medium">Bónus para o indicado</label>
              <input type="number" step="0.01" {...register('referral_bonus.referee', { valueAsNumber: true })} className="w-full mt-1 p-2 border rounded" />
            </div>
          </div>
        </div>

        <div>
          <h2 className="text-xl font-semibold">Taxas e Comissões</h2>
          <p className="text-sm text-gray-500 mb-4">Defina a taxa de comissão sobre as transações.</p>
          <div>
            <label className="block text-sm font-medium">Taxa de Comissão (ex: 0.10 para 10%)</label>
            <input type="number" step="0.01" {...register('transaction_commission_rate.rate', { valueAsNumber: true })} className="w-full mt-1 p-2 border rounded" />
          </div>
        </div>
        
        <div className="flex justify-end">
            <button type="submit" disabled={isSubmitting || !isDirty} className="flex items-center bg-primary-600 text-white px-6 py-2 rounded-lg hover:bg-primary-700 disabled:opacity-50">
                {isSubmitting ? <Loader2 className="w-5 h-5 mr-2 animate-spin" /> : null}
                Guardar Alterações
            </button>
        </div>
      </form>
    </div>
  );
}
