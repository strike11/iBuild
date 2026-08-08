-- Point Hills Blue media URLs at hillsblue.png (replaces hillsblue.jpg).
BEGIN;
SET LOCAL app.role = 'service';

UPDATE media
SET url = REPLACE(url, 'hillsblue.jpg', 'hillsblue.png')
WHERE url LIKE '%hillsblue.jpg%';

COMMIT;

SELECT id, url FROM media WHERE url LIKE '%hillsblue%';
