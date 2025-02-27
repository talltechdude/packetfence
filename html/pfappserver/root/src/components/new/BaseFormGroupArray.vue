<template>
  <b-form-group ref="form-group"
    class="base-form-group-array"
    :class="{
      'mb-0': !columnLabel
    }"
    :state="inputState"
    :labelCols="labelCols"
    :label="columnLabel"
  >
    <b-input-group
      :class="{
        'has-valid': inputState === true,
        'has-invalid': inputState === false
      }"
      :data-num="inputLength"
    >
      <b-button v-if="!inputLength" @click="itemAdd()"
        :variant="(inputState === false) ? 'outline-danger' : 'outline-secondary'"
        :disabled="isLocked"
      >{{ buttonLabel || $t('Add') }}</b-button>

      <div v-else
        class="base-form-group-array-items mx-3"
      >

        <slot name="header"/>

        <b-row v-for="(item, index) in inputValue" :key="index"
          class="base-form-group-array-item align-items-center"
          :class="{
            'is-firstchild': index === 0,
            'is-lastchild': index === inputValue.length - 1
          }"
        >
          <b-col class="text-center">
            <span class="col-form-label ">{{ index + 1 }}</span>
          </b-col>
          <b-col cols="10" class="py-1">

            <component :is="childComponent"
              :namespace="`${namespace}.${index}`"
            />

          </b-col>
          <b-col>
            <b-link @click="itemDelete(index)"
              :class="{
                'text-black-50': isLocked,
                'text-primary': !isLocked && actionKey,
                'text-secondary': !isLocked && !actionKey
              }"
              :disabled="isLocked"
              v-b-tooltip.hover.left.d300 :title="actionKey ? $t('Delete All') : $t('Delete Row')"
            >
              <icon name="minus-circle" class="cursor-pointer mx-1"/>
            </b-link>
            <b-link @click="itemAdd(index + 1)"
              :class="{
                'text-black-50': isLocked,
                'text-primary': !isLocked && actionKey,
                'text-secondary': !isLocked && !actionKey
              }"
              :disabled="isLocked"
              v-b-tooltip.hover.left.d300 :title="actionKey ? $t('Clone Row') : $t('Add Row')"
            >
              <icon name="plus-circle" class="cursor-pointer mx-1"/>
            </b-link>
          </b-col>
        </b-row>
      </div>
    </b-input-group>
    <template v-slot:description v-if="inputText">
      <div v-html="inputText"/>
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
import { toRefs, unref } from '@vue/composition-api'

import useEventActionKey from '@/composables/useEventActionKey'
import { useArrayDraggable, useArrayDraggableProps } from '@/composables/useArrayDraggable'
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
  ...useArrayDraggableProps,

  buttonLabel: {
    type: String
  }
}

const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)

  const {
    defaultItem
  } = toRefs(metaProps)

  const {
    text,
    isLocked
  } = useInput(metaProps, context)

  const {
    value,
    length,
    onInput,
    onChange
  } = useInputValue(metaProps, context)

  const {
    add: draggableAdd,
    copy: draggableCopy,
    remove: draggableRemove,
    truncate: draggableTruncate
  } = useArrayDraggable(props, context, value, onChange)

  const {
    state,
    invalidFeedback,
    validFeedback
  } = useInputValidator(metaProps, value, true) // recursive

  const actionKey = useEventActionKey(/* document */)

  const itemAdd = (index = 0) => {
    const _value = unref(value)
    const isCopy = unref(actionKey) && index - 1 in _value
    if (isCopy)
      draggableCopy(index - 1, index)
    else
      draggableAdd(index, unref(defaultItem))
  }

  const itemDelete = (index) => {
    const isAll = unref(actionKey)
    if (isAll)
      draggableTruncate()
    else
      draggableRemove(index)
  }

  return {
    // useInput
    inputText: text,
    isLocked,

    // useInputValue
    inputValue: value,
    inputLength: length,
    onInput,
    onChange,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback,

    actionKey,
    itemAdd,
    itemDelete
  }
}

// @vue/component
export default {
  name: 'base-form-group-array',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
.base-form-group-array {
  & > .form-row > div > .input-group {
    border: 1px solid transparent;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);

    & > div > .row {
      & > .col > a {
        outline: 0; /* disable highlighting on tabIndex */
      }
    }
    &.has-invalid:not([data-num="0"]) {
      border-color: $form-feedback-invalid-color;
      box-shadow: 0 0 0 $input-focus-width rgba($form-feedback-invalid-color, .25);
    }
    &.has-valid:not([data-num="0"]) {
      border-color: $form-feedback-valid-color;
      box-shadow: 0 0 0 $input-focus-width rgba($form-feedback-valid-color, .25);
    }
  }
}
.base-form-group-array-items {
  flex-grow: 100;
  & > .base-form-group-array-item {
    &:not(.is-lastchild) {
      border-bottom: $input-border-width solid $input-focus-bg;
    }
  }
}
</style>
