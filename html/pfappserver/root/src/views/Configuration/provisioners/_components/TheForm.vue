<template>
  <b-container class="px-0" fluid>
    <component v-if="formType"
      :is="formType" v-bind="$props"
    />

    <base-container-loading v-else-if="isLoading"
      :title="$i18n.t('Building Form')"
      :text="$i18n.t('Hold on a moment while we render it...')"
      spin
    />

    <base-container-loading v-else
      :title="$i18n.t('Unhandled pki provider type')"
      icon="question-circle"
    />
  </b-container>
</template>
<script>
import { computed, toRefs, unref } from '@vue/composition-api'
import { useFormProps as props } from '../_composables/useForm'
import { BaseContainerLoading } from '@/components/new/'
import FormTypeAccept from './FormTypeAccept'
import FormTypeAirwatch from './FormTypeAirwatch'
import FormTypeAndroid from './FormTypeAndroid'
import FormTypeGoogleWorkspaceChromebook from './FormTypeGoogleWorkspaceChromebook'
import FormTypeDeny from './FormTypeDeny'
import FormTypeDpsk from './FormTypeDpsk'
import FormTypeIbm from './FormTypeIbm'
import FormTypeIntune from './FormTypeIntune'
import FormTypeJamf from './FormTypeJamf'
import FormTypeMobileconfig from './FormTypeMobileconfig'
import FormTypeMobileiron from './FormTypeMobileiron'
import FormTypeOpswat from './FormTypeOpswat'
import FormTypeSentinelone from './FormTypeSentinelone'
import FormTypeSepm from './FormTypeSepm'
import FormTypeServicenow from './FormTypeServicenow'
import FormTypeSymantec from './FormTypeSymantec'
import FormTypeWindows from './FormTypeWindows'

const components = {
  BaseContainerLoading,

  FormTypeAccept,
  FormTypeAirwatch,
  FormTypeAndroid,
  FormTypeGoogleWorkspaceChromebook,
  FormTypeDeny,
  FormTypeDpsk,
  FormTypeIbm,
  FormTypeIntune,
  FormTypeJamf,
  FormTypeMobileconfig,
  FormTypeMobileiron,
  FormTypeOpswat,
  FormTypeSentinelone,
  FormTypeSepm,
  FormTypeServicenow,
  FormTypeSymantec,
  FormTypeWindows
}

export const setup = (props) => {

  const {
    form
  } = toRefs(props)

  const formType = computed(() => {
    const { type } = unref(form)
    switch(unref(type)) {
      case 'accept':                      return FormTypeAccept // break
      case 'airwatch':                    return FormTypeAirwatch //break
      case 'android':                     return FormTypeAndroid //break
      case 'deny':                        return FormTypeDeny //break
      case 'dpsk':                        return FormTypeDpsk //break
      case 'google_workspace_chromebook': return FormTypeGoogleWorkspaceChromebook //break
      case 'ibm':                         return FormTypeIbm //break
      case 'intune':                      return FormTypeIntune //break
      case 'jamf':                        return FormTypeJamf //break
      case 'mobileconfig':                return FormTypeMobileconfig //break
      case 'mobileiron':                  return FormTypeMobileiron //break
      case 'opswat':                      return FormTypeOpswat //break
      case 'sentinelone':                 return FormTypeSentinelone //break
      case 'sepm':                        return FormTypeSepm //break
      case 'servicenow':                  return FormTypeServicenow //break
      case 'symantec':                    return FormTypeSymantec //break
      case 'windows':                     return FormTypeWindows // break
      default:                            return undefined
    }
  })

  return {
    formType
  }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
