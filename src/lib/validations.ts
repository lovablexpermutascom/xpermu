import * as yup from 'yup';

export const listingSchema = yup.object().shape({
  title: yup.string().required('O título é obrigatório').min(5, 'O título deve ter pelo menos 5 caracteres'),
  description: yup.string().required('A descrição é obrigatória').min(20, 'A descrição deve ter pelo menos 20 caracteres'),
  price: yup.number().typeError('O preço deve ser um número').required('O preço é obrigatório').positive('O preço deve ser positivo'),
  category_id: yup.string().required('A categoria é obrigatória'),
  location: yup.string().required('A localização é obrigatória'),
  // Note: Image validation will be handled separately
});
