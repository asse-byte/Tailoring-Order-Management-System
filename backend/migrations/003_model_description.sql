-- Prêt-à-porter: the app's model form has a description field; store it.
-- (Media images/videos already have their table: model_media, 001.)

ALTER TABLE pret_a_porter_models
  ADD COLUMN description text NOT NULL DEFAULT '';
