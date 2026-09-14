<script setup lang="ts">
const config = useRuntimeConfig();
useHead({ meta: [{ name: 'robots', content: config.public.indexable ? 'index, follow' : 'noindex, nofollow' }] });
</script>

<template>
  <NuxtPage />
</template>
