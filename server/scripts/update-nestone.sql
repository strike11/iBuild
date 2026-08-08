-- Patch live NestOne row (status, district, progress) without wiping the catalogue.
-- Usage: psql ... -f scripts/update-nestone.sql && docker compose restart api

BEGIN;
SET LOCAL app.role = 'service';

UPDATE projects
SET
  status = 'ready',
  district = 'Shayxontohur',
  address = 'Amir Temur shoh ko''chasi, Shayxontohur, Tashkent',
  description =
    'NestOne is a completed mixed-use complex in Shayxontohur: sale and rent '
    'apartments in a 10-storey living tower plus Class-A offices with live '
    'availability on an interactive floor grid. Underground parking, gym, and concierge.',
  tags = ARRAY[
    'Premium',
    'Ready to move',
    'Apartments',
    'Offices',
    'Rent',
    'Installments'
  ],
  construction_progress = 100,
  planned_progress = 100,
  completion_date = '2024-12-01'::timestamptz
WHERE id = 'prj-nestone';

UPDATE buildings
SET
  construction_progress = 100,
  completion_date = '2024-12-01'::timestamptz
WHERE project_id = 'prj-nestone';

UPDATE units
SET
  is_offplan = false,
  finishing = 'Turnkey'
WHERE building_id IN (
  SELECT id FROM buildings WHERE project_id = 'prj-nestone'
);

UPDATE offers
SET
  title = 'Flexible installment plan',
  description = '25% down payment, balance in equal monthly payments.',
  ends_at = NULL,
  term_months = 36
WHERE id = 'off-nestone-installment';

COMMIT;

SELECT id, name, status, district, construction_progress FROM projects WHERE id = 'prj-nestone';
