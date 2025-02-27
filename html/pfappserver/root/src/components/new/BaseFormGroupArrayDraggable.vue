<template>
  <b-form-group ref="form-group"
    class="base-form-group-array-draggable"
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
        'has-invalid': inputState === false,
        'is-striped': isStriped
      }"
      :data-num="inputLength"
    >
      <b-button v-if="!inputLength" @click="itemAdd()"
        :variant="(inputState === false) ? 'outline-danger' : 'outline-secondary'"
        :disabled="isLocked"
      >{{ buttonLabel || $t('Add') }}</b-button>

      <draggable v-else ref="draggableRef"
        class="base-form-group-array-draggable-items w-100 mx-3"
        handle=".draggable-handle"
        ghost-class="draggable-copy"
        v-on="draggableListeners"
      >
        <b-row v-for="(item, index) in inputValue" :key="draggableKeys[index]"
          class="base-form-group-array-draggable-item align-items-center"
          :class="{
            'is-firstchild': index === 0,
            'is-lastchild': index === inputValue.length - 1
          }"
        >
          <b-col class="text-center" :class="{
            'draggable-on': isSortable,
            'draggable-off': !isSortable
          }">
            <icon v-if="isSortable"
              class="draggable-handle" name="th" scale="1.5"
              v-b-tooltip.hover.left.d300 :title="$t('Click and drag to re-order')"
            />
            <span class="draggable-index col-form-label ">{{ index + 1 }}</span>
          </b-col>
          <b-col cols="10" class="py-1">

            <component :is="childComponent" :ref="draggableKeys[index]"
              :namespace="`${namespace}.${index}`"
              v-bind="draggableProps"
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
      </draggable>
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
import { computed, toRefs, unref } from '@vue/composition-api'
const draggable = () => import(/* webpackChunkName: "Libs" */ 'vuedraggable')

const components = {
  draggable
}

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

  const {
    striped
  } = toRefs(props)

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
    draggableRef,
    draggableKeys,

    add: draggableAdd,
    copy: draggableCopy,
    remove: draggableRemove,
    truncate: draggableTruncate,

    draggableListeners,
    draggableProps
  } = useArrayDraggable(props, context, value, onChange)

  const {
    state,
    invalidFeedback,
    validFeedback
  } = useInputValidator(metaProps, value, true) // recursive

  const actionKey = useEventActionKey(/* document */)

  const isSortable = computed(() => !unref(isLocked) && unref(value).length > 1)

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

    // useArrayDraggable
    draggableRef,
    draggableKeys,
    draggableListeners,
    draggableProps,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback,

    isSortable,
    isStriped: striped,
    actionKey,
    itemAdd,
    itemDelete
  }
}

// @vue/component
export default {
  name: 'base-form-group-array-draggable',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">
.draggable-copy {
  background-color: $primary !important;
  path, /* svg icons */
  * {
    color: $white !important;
    border-color: transparent !important;
  }
  /* TODO: Bugfix
  button.btn {
    color: $white !important;
    border: 1px solid $white !important;
    border-color: $white !important;
  }
  */
  input,
  select,
  .multiselect__single {
    color: $primary !important;
  }
  .base-input-range {
    background-color: $white !important;
    .handle {
      background-color: $primary !important;
      color: $white !important;
    }

  }

}
.base-form-group-array-draggable {
  .draggable-off > .draggable-handle,
  .draggable-on:not(:hover) > .draggable-handle,
  .draggable-on:hover > .draggable-index {
    display: none;
  }
  & > .form-row > div > .input-group {
    border: 1px solid transparent;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);

    & > div > .row {
      & > .col > a {
        outline: 0; /* disable highlighting on tabIndex */
      }
    }
    &.is-striped > div > .row {
      &:nth-child(even) {
        background-color: $table-border-color;
      }
      &:nth-child(odd) {
        background-color: $white;
      }
    }
    &:not(.is-striped) > div > .row:not(:last-child) {
      border-bottom: 1px solid $table-border-color;
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
</style>
