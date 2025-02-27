<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Hostname or IP Address')"
      :disabled="!isNew && !isClone"
    />

    <form-group-tenant-id namespace="tenant_id"
      :column-label="$i18n.t('Tenant ID')"
      :text="$i18n.t('Leave empty for the default tenant.')"
    />

    <form-group-username namespace="username"
      :column-label="$i18n.t('Username')"
    />

    <form-group-password namespace="password"
      :column-label="$i18n.t('Secret or Key')"
    />

    <form-group-port namespace="port"
      :column-label="$i18n.t('Port of the service')"
      :text="$i18n.t('If you use an alternative port, please specify.')"
    />

    <form-group-categories namespace="categories"
      :column-label="$i18n.t('Roles')"
      :text="$i18n.t('Nodes with the selected roles will be affected.')"
    />

    <form-group-networks namespace="networks"
      :column-label="$i18n.t('Networks on which to do SSO')"
      :text="$i18n.t('Comma delimited list of networks on which the SSO applies.\nFormat : 192.168.0.0/24')"
    />

    <form-group-cache-updates namespace="cache_updates"
      :column-label="$i18n.t('Cache updates')"
      :text="$i18n.t(`Enable this to debounce updates to the Firewall.\nBy default, PacketFence will send a SSO on every DHCP request for every device. Enabling this enables 'sleep' periods during which the update is not sent if the informations stay the same.`)"
    />

    <form-group-cache-timeout namespace="cache_timeout"
      :column-label="$i18n.t('Cache timeout')"
      :text="$i18n.t(`Adjust the 'Cache timeout' to half the expiration delay in your firewall.\nYour DHCP renewal interval should match this value.`)"
    />

    <form-group-username-format namespace="username_format"
      :column-label="$i18n.t('Username format')"
      :text="$i18n.t('Defines how to format the username that is sent to your firewall. $username represents the username and $realm represents the realm of your user if applicable. $pf_username represents the unstripped username as it is stored in the PacketFence database. If left empty, it will use the username as stored in PacketFence (value of $pf_username).')"
    />

    <form-group-default-realm namespace="default_realm"
      :column-label="$i18n.t('Default realm')"
      :text="$i18n.t('The default realm to be used while formatting the username when no realm can be extracted from the username.')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupCacheTimeout,
  FormGroupCacheUpdates,
  FormGroupCategories,
  FormGroupDefaultRealm,
  FormGroupIdentifier,
  FormGroupNetworks,
  FormGroupPassword,
  FormGroupPort,
  FormGroupUsername,
  FormGroupUsernameFormat,
  FormGroupTenantId,
} from './'

const components = {
  BaseForm,

  FormGroupCacheTimeout,
  FormGroupCacheUpdates,
  FormGroupCategories,
  FormGroupDefaultRealm,
  FormGroupIdentifier,
  FormGroupNetworks,
  FormGroupPassword,
  FormGroupPort,
  FormGroupUsername,
  FormGroupUsernameFormat,
  FormGroupTenantId,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-barracuda-ng',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
