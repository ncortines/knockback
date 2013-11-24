class ORM
  constructor: ->
    @adapters = []

  initialize: -> @adapters = _.select(@adapters, (adapter) -> adapter.isAvailable())

  inferCreator: (model, key) ->
    return unless @adapters.length
    @initialize() unless @initialized

    return creator for adpater in @adapters when creator = adpater.inferCreator(model, key)
    return

  bind: (model, key, update, path) ->
    return unless @adapters.length
    @initialize() unless @initialized

    return unbind_fn for adpater in @adapters when unbind_fn = adpater.bind(model, key, update, path)
    return

kb.orm = new ORM()

class ORMAdapter_BackboneORM
  isAvailable: ->
    try kb.BackboneORM = if not @BackboneORM and (typeof(require) isnt 'undefined') then require('backbone-orm') else @BackboneORM catch e
    return !!kb.BackboneORM

  relationType: (model, key) ->
    return null unless (model.schema and _.isFunction(model.relation))
    return null unless relation = model.relation(key)
    return if relation.type is 'hasMany' then KB_TYPE_COLLECTION else KB_TYPE_MODEL

  inferCreator: (model, key) ->
    return null unless type = @relationType(model, key)
    return if type is KB_TYPE_COLLECTION then kb.CollectionObservable else kb.ViewModel

  bind: (model, key, update, path) ->
    return null unless type = @relationType(model, key)
    rel_fn = (model) ->
      not kb.statistics or kb.statistics.addModelEvent({name: 'update (backbone-orm)', model: model, key: key, path: path})
      update()

    # if type is KB_TYPE_COLLECTION
    #   model.bind("#{event}:#{key}", rel_fn) for event in events = ['change', 'add', 'remove']
    # else
    model.bind("add", rel_fn)
    model.bind("remove", rel_fn)
    model.bind("change:#{key}", rel_fn)

    return ->
      # if type is KB_TYPE_COLLECTION
      #   model.unbind("#{event}:#{key}", rel_fn) for event in events
      # else
      model.unbind("add", rel_fn)
      model.unbind("remove", rel_fn)
      model.unbind("change:#{key}", rel_fn)
      return

kb.orm.adapters.push(new ORMAdapter_BackboneORM())

class ORMAdapter_BackboneRelational
  isAvailable: ->
    try require('backbone-relational') if kb.Backbone and not kb.Backbone.RelationalModel and (typeof(require) isnt 'undefined') catch e
    return !!kb.Backbone?.RelationalModel

  relationType: (model, key) ->
    return null unless model instanceof kb.Backbone.RelationalModel
    return null unless relation = _.find(model.getRelations(), (test) -> return test.key is key)
    return if (relation.collectionType or _.isArray(relation.keyContents)) then KB_TYPE_COLLECTION else KB_TYPE_MODEL

  inferCreator: (model, key) ->
    return null unless type = @relationType(model, key)
    return if type is KB_TYPE_COLLECTION then kb.CollectionObservable else kb.ViewModel

  bind: (model, key, update, path) ->
    return null unless type = @relationType(model, key)
    rel_fn = (model) ->
      not kb.statistics or kb.statistics.addModelEvent({name: 'update (relational)', model: model, key: key, path: path})
      update()

    # VERSIONING: pre Backbone-Relational 0.8.0
    events = if Backbone.Relation.prototype.sanitizeOptions then ['update', 'add', 'remove'] else ['change', 'add', 'remove']
    if type is KB_TYPE_COLLECTION
      model.bind("#{event}:#{key}", rel_fn) for event in events
    else
      model.bind("#{events[0]}:#{key}", rel_fn)

    return ->
      if type is KB_TYPE_COLLECTION
        model.unbind("#{event}:#{key}", rel_fn) for event in events
      else
        model.unbind("#{events[0]}:#{key}", rel_fn)
      return

kb.orm.adapters.push(new ORMAdapter_BackboneRelational())