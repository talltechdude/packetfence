<template>
  <b-form @submit.prevent="onSearch" @reset.prevent="onReset" id="form">
    <div class="input-group">
      <div class="input-group-prepend">
        <div class="input-group-text"><icon name="search"></icon></div>
      </div>
      <b-form-input :value="value" @input="onInput" v-focus id="container" type="text" :disabled="disabled" :placeholder="placeholder"
        :title="title" v-b-tooltip:form.v-primary.hover.top.d300="{ customClass: 'tooltip-grow' }" />
      <b-button class="ml-1" type="reset" variant="secondary" :disabled="disabled">{{ $t('Clear') }}</b-button>
      <b-button-group>
        <!-- saved search button -->
        <base-button-save-search v-if="saveSearchNamespace"
          :value="value" @input="onInput" :id="value" class="ml-1"
          :disabled="disabled"
          :save-search-namespace="saveSearchNamespace"
          :use-search="useSearch"
          @search="onSearch"
          @load="onLoad"
        />
        <!-- normal button -->
        <b-button v-else
          class="ml-1" type="submit" variant="primary" :disabled="disabled">{{ $t('Search') }}</b-button>
        <!-- additional buttons -->
        <slot/>
      </b-button-group>
    </div>
  </b-form>
</template>
<script>
import BaseButtonSaveSearch from './BaseButtonSaveSearch'

const components = {
  BaseButtonSaveSearch
}

import { focus } from '@/directives'
const directives = {
  focus
}

import i18n from '@/utils/locale'

const props = {
  value: {
    type: String
  },
  placeholder: {
    type: String,
    default: i18n.t('Enter search criteria')
  },
  title: {
    type: String
  },
  disabled: {
    type: Boolean
  },
  saveSearchNamespace: {
    type: String
  },
  useSearch: {
    type: Function
  }
}

import { toRefs } from '@vue/composition-api'

const setup = (props, context) => {
  const {
    value
  } = toRefs(props)

  const { emit, root: { $router } = {} } = context

  const onInput = value => emit('input', value)
  const onReset = () => emit('reset', true)
  const onSearch = () => emit('search', value.value)
  const onMode = () => emit('mode', true)
  const onLoad = search => {
    const { currentRoute: { path } = {} } = $router
    const { id, query: conditionBasic, ...rest } = search // strip id, rename query
    const _query = { conditionBasic, ...rest }
    const query = Object.keys(_query).reduce((query, param) => {
      query[param] = JSON.stringify(_query[param])
      return query
    }, {})
    $router.push({ path, query })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
  }

  return {
    onInput,
    onReset,
    onSearch,
    onMode,
    onLoad
  }
}

// @vue/component
export default {
  name: 'base-search-input-basic',
  inheritAttrs: false,
  components,
  directives,
  props,
  setup
}
</script>
<style lang="scss">
.tooltip-grow {
  .tooltip-inner {
    max-width: 100vh;
  }
}
</style>
