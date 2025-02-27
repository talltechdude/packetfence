import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  prefixRouteName: { // from Configurator
    type: String,
    default: ''
  }
}

export const useItemDefaults = (_, props) => {
  const {
    id
  } = toRefs(props)
  return { id: id.value, type: 'none' }
}

export const useItemTitle = (props, context, form) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    const { master = false } = form.value || {}
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Interface <code>{id}</code>', { id: ((master) ? master : id.value) })
      case isClone.value:
        return i18n.t('Clone Interface <code>{id}</code>', { id: ((master) ? master : id.value) })
      default:
        return i18n.t('New Interface VLAN <code>{id}</code>', { id: ((master) ? master : id.value) })
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  return computed(() => {
    const { master = false } = form.value || {}
    if (master) {
      const { 1: vlanFromId = null } = id.value.split('.')
      return `VLAN ${vlanFromId}`
    }
    return // don't show
  })
}

export { useRouter } from '../_router'

export { useStore } from '../_store'
