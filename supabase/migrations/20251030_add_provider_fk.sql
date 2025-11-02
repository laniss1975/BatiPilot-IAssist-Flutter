-- Add foreign key constraint between ai_provider_configs and ai_providers
ALTER TABLE public.ai_provider_configs
ADD CONSTRAINT fk_ai_provider_configs_provider
FOREIGN KEY (provider_name) 
REFERENCES public.ai_providers(provider_key)
ON DELETE RESTRICT
ON UPDATE CASCADE;

-- Create index for better performance on joins
CREATE INDEX IF NOT EXISTS idx_ai_provider_configs_provider_name 
ON public.ai_provider_configs(provider_name);
