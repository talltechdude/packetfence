<template>
  <b-form-group ref="form-group"
    class="base-form-group"
    :class="{
      'mb-0': !columnLabel
    }"
    :state="inputState"
    :labelCols="labelCols"
    :label="columnLabel"
  >
    <b-input-group ref="input-group"
      class="is-borders"
      :class="{
        'is-focus': isFocus || isShown,
        'is-blur': !(isFocus || isShown),
        'is-valid': inputState === true,
        'is-invalid': inputState === false
      }"
    >
      <b-form-input ref="input"
        class="base-form-group-input base-input"
        :disabled="isLocked"
        :readonly="inputReadonly"
        :state="inputState"
        :placeholder="inputPlaceholder"
        :tabIndex="inputTabIndex"
        :type="inputType"
        :value="inputValue"
        @input="onInput"
        @change="onChange"
        @focus="onFocus"
        @blur="onBlur"
      />
      <template v-slot:append>
        <b-button v-if="isLocked"
          class="input-group-text"
          :disabled="true"
          tabIndex="-1"
        >
          <icon ref="icon-lock"
            name="lock"
          />
        </b-button>
        <b-button v-else
          ref="popoverButtonRef"
          class="input-group-text"
          :disabled="isLocked"
          tabIndex="-1"
          @click="onToggle"
        >
          <icon ref="icon-popover"
            name="calendar-alt"
          />
        </b-button>
        <b-popover :show.sync="isShown"
          ref="popover"
          custom-class="popover-full popover-no-padding"
          placement="top"
          triggers="manual"
          :target="popoverTarget"
          @hidden="onHidden"
          @shown="onShown"
        >
          <b-row class="text-center" no-gutters>
            <b-col cols="12" class="text-center py-1">
              <b-calendar
                :value="inputValueDate"
                class="align-self-center"
                :locale="$i18n.locale"
                @input="onDate"
                label-help=""
                hide-header
                block
              ></b-calendar>
            </b-col>
          </b-row>
          <b-row class="text-center" no-gutters>
            <b-col cols="12" class="text-center py-1">
              <b-time
                :value="inputValueTime"
                class="align-self-center"
                :locale="$i18n.locale"
                @input="onTime"
                hide-header
                show-seconds
              ></b-time>
            </b-col>
          </b-row>
        </b-popover>
      </template>
    </b-input-group>
    <template v-slot:description v-if="inputText || inputApiFeedback">
      <div v-if="inputApiFeedback" v-html="inputApiFeedback" class="text-warning"/>
      <div v-if="inputText" v-html="inputText"/>
    </template>
    <template v-slot:invalid-feedback v-if="inputInvalidFeedback">
      <div v-html="inputInvalidFeedback"/>
    </template>
    <template v-slot:valid-feedback v-if="inputValidFeedback">
      <div v-html="inputValidFeedback"/>
    </template>
  </b-form-group>
</template>
<script>
import { parse, format } from 'date-fns'
import { computed, onBeforeUnmount, onMounted, ref, toRefs } from '@vue/composition-api'
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

export const props = {
  ...useFormGroupProps,
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps,

  min: {
    type: [Date, String]
  },
  max: {
    type: [Date, String]
  },
  dateFormat: {
    type: String,
    default: 'YYYY-MM-DD'
  },
  timeFormat: {
    type: String,
    default: 'HH:mm:ss'
  }
}

export const setup = (props, context) => {

  const {
    dateFormat,
    timeFormat
  } = toRefs(props)

  const metaProps = useInputMeta(props, context)

  const { refs } = context

  const {
    placeholder,
    readonly,
    tabIndex,
    text,
    type,
    isFocus,
    isLocked,
    onFocus,
    onBlur,
    doFocus
  } = useInput(metaProps, context)

  const {
    value,
    onInput,
    onChange
  } = useInputValue(metaProps, context)

  const {
    state,
    invalidFeedback,
    validFeedback,
    apiFeedback
  } = useInputValidator(metaProps, value)

  const _onDocumentClickHandler = event => {
    const { target } = event
    const {
      input: { $el: inputEl } = {},
      popover: { $_toolpop: { $children: { 0: { $el: popoverEl } = {} } = {} } = {} } = {}
    } = refs
    if (!inputEl.contains(target) && !popoverEl.contains(target))
      isShown.value = false
  }

  const _onDocumentFocusHandler = event => {
    const { target } = event
    const {
      input: { $el: inputEl } = {}
    } = refs
    if (['input', 'textarea'].includes(target.tagName.toLowerCase()) && !inputEl.isSameNode(target))
      isShown.value = false
  }

  const isShown = ref(false)
  const onShown = () => {
    document.addEventListener('click', _onDocumentClickHandler)
    document.addEventListener('focus', _onDocumentFocusHandler, true)
    isShown.value = true
  }
  const onHidden = () => {
    document.removeEventListener('click', _onDocumentClickHandler)
    document.removeEventListener('focus', _onDocumentFocusHandler, true)
    isShown.value = false
  }
  onBeforeUnmount(() => {
    document.removeEventListener('click', _onDocumentClickHandler)
    document.removeEventListener('focus', _onDocumentFocusHandler, true)
  })
  const onToggle = () => { isShown.value = !isShown.value }

  const popoverTarget = ref(document.createElement('input'))
  onMounted(() => {
    const { 'form-group': { $el } = {} } = refs
    popoverTarget.value = $el.querySelector('[role="group"]')
  })

  const inputValueDate = computed(() => {
    if (value.value && value.value.charAt(0) !== '0') {
      const parsed = parse(value.value, `${dateFormat.value} ${timeFormat.value}`)
      return format(parsed, 'YYYY-MM-DD')
    }
    return format(new Date(), 'YYYY-MM-DD')
  })

  const inputValueTime = computed(() => {
    if (value.value) {
      const parsed = parse(value.value, `${dateFormat.value} ${timeFormat.value}`)
      return format(parsed, 'HH:mm:ss')
    }
    return '00:00:00'
  })

  const onDate = newDate => {
    if (newDate && !isFocus.value) {
      const parsedDate = parse(newDate, 'YYYY-MM-DD')
      const parsedTime = parse(`1970-01-01 ${inputValueTime.value}`, 'YYYY-MM-DD HH:mm:ss')
      onInput(`${format(parsedDate, dateFormat.value)} ${format(parsedTime, timeFormat.value)}`)
    }
  }

  const onTime = newTime => {
    if (newTime && !isFocus.value) {
      const parsedDate = parse(inputValueDate.value, 'YYYY-MM-DD')
      const parsedTime = parse(`1970-01-01 ${newTime}`, 'YYYY-MM-DD HH:mm:ss')
      onInput(`${format(parsedDate, dateFormat.value)} ${format(parsedTime, timeFormat.value)}`)
    }
  }

  return {
    // useInput
    inputPlaceholder: placeholder,
    inputReadonly: readonly,
    inputTabIndex: tabIndex,
    inputText: text,
    inputType: type,
    isFocus,
    isLocked,
    onFocus,
    onBlur,
    doFocus,

    // useInputValue
    inputValue: value,
    onInput,
    onChange,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback,
    inputApiFeedback: apiFeedback,

    isShown,
    onShown,
    onHidden,
    onToggle,

    popoverTarget,
    inputValueDate,
    inputValueTime,
    onDate,
    onTime
  }
}

// @vue/component
export default {
  name: 'base-form-group-input-date-time',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
.base-form-group-input-date {
  border-radius: $border-radius !important;
}
</style>
