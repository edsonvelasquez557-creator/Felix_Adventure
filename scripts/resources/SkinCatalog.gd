class_name SkinCatalog
extends Resource
## Catálogo de skins disponibles en la tienda (orden = orden de aparición).
##
## Añadir una skin nueva no requiere tocar código: crea un recurso SkinData,
## asígnale su hoja de sprites y agrégalo a la lista [member skins].

@export var skins: Array[SkinData] = []
