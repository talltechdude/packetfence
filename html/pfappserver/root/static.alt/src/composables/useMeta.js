import { computed, inject, reactive, ref, toRefs, unref, set, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const getMetaNamespace = (ns, o) => ns.reduce((xs, x) => {
  if (xs) {
    if (x in xs)
      return xs[x]
    else if ('type' in xs) {
      if (xs.type === 'array' && 'item' in xs && `${+x}` === `${x}`)
        return xs.item
      else if (xs.type === 'object' && 'properties' in xs && x in xs.properties)
        return xs.properties[x]
    }
  }
  return {}
}, o)

export const useInputMetaProps = {
  namespace: {
    type: String
  }
}

export const useInputMeta = (props) => {

  const {
    namespace
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring

  // defaults (dereferenced)
  let localProps = reactive({})
  watch(
    props,
    props => {
      for(let prop in props) {
        set(localProps, prop, props[prop])
      }
    },
    { immediate: true }
  )

  if (unref(namespace)) {
    // use namespace
    const meta = inject('meta', ref({}))
    const namespaceArr = computed(() => unref(namespace).split('.'))
    const namespaceMeta = computed(() => getMetaNamespace(unref(namespaceArr), unref(meta)))

    watch(
      namespaceMeta,
      namespaceMeta => {
        let _namespaceMeta = unref(namespaceMeta)
        let { type, item } = _namespaceMeta
        if (type === 'array')
          _namespaceMeta = item
        const {
          allowed: metaAllowed,
          min_length: metaMinLength = undefined,
          max_length: metaMaxLength = undefined,
          min_value: metaMinValue = undefined,
          max_value: metaMaxValue = undefined,
          pattern: metaPattern,
          placeholder: metaPlaceholder,
          required: metaRequired,
          type: metaType
        } = _namespaceMeta

        // allowed
        if (metaAllowed) {
          set(localProps, 'options', metaAllowed)
        }

        // placeholder
        if (metaPlaceholder)
          set(localProps, 'placeholder', metaPlaceholder)

        // type
        switch(metaType) {
          case 'integer':
            set(localProps, 'type', 'number')
            break
          default:
            set(localProps, 'type', 'text')
        }
      },
      { immediate: true }
    )
  }

  return localProps
}

export const useFormMetaSchema = (meta, schema) => {

  const getSchemaFromMeta = (meta, type = 'object') => {
    let schema
    const {
      item: { type: itemType, properties = {} } = {},
      min_length = undefined,
      max_length = undefined,
      min_value = undefined,
      max_value = undefined,
      pattern,
      required
    } = meta
    let object = {}

    switch (type) {
      case 'object':
        for (let property in meta) {
          const { type } = meta[property]
          object[property] = getSchemaFromMeta(meta[property], type)
        }
        schema = yup.object(object)
        break

      case 'array':
        object = getSchemaFromMeta(properties, itemType)
        schema = yup.array().of(object)

        if (required)
          schema = schema.required()

        break

      case 'string':
        schema = yup.string().nullable()

        if (required)
          schema = schema.required()

        if (pattern) {
          const { regex, message } = pattern
          const re = new RegExp(`^${regex}$`)
          schema = schema.matches(re, message)
        }

        if (min_value !== undefined)
          schema = schema.minAsInt(min_value)

        if (max_value !== undefined)
          schema = schema.maxAsInt(max_value)

        break
    }

    if (min_length !== undefined)
      schema = schema.min(min_length)

    if (max_length !== undefined)
      schema = schema.max(max_length)

    return schema
  }

  return computed(() => unref(schema).concat(
    getSchemaFromMeta(meta.value)
  ))
}
