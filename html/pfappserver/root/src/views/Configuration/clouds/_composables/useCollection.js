import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { types } from '../config'

export const useItemProps = {
  id: {
    type: String
  },
  cloudType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    cloudType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: cloudType.value }
}

export const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Cloud Service <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Cloud Service <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Cloud Service')
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    cloudType
  } = toRefs(props)
  return computed(() => {
    const type = cloudType.value || form.value.type
    return types[type]
  })
}

export { useRouter } from '../_router'

export { useStore } from '../_store'

import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import makeSearch from '@/store/factory/search'
import api from '../_api'
export const useSearch = makeSearch('clouds', {
  api,
  columns: [
    {
      key: 'selected',
      thStyle: 'width: 40px;', tdClass: 'text-center',
      locked: true
    },
    {
      key: 'id',
      label: 'Name', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true
    },
    {
      key: 'type',
      label: 'Cloud Type', // i18n defer
      required: true,
      searchable: true,
      sortable: true,
      visible: true,
      formatter: value => types[value]
    },
    {
      key: 'buttons',
      class: 'text-right p-0',
      locked: true
    }
  ],
  fields: [
    {
      value: 'id',
      text: i18n.t('Name'),
      types: [conditionType.SUBSTRING]
    },
    {
      value: 'type',
      text: i18n.t('Cloud Type'),
      types: [conditionType.SUBSTRING]
    }
  ],
  sortBy: 'id'
})
