<script setup lang="ts">
const config = useRuntimeConfig();
const publication = config.public.publication;
useHead({ meta: [{ name: 'robots', content: publication.indexable ? 'index, follow' : 'noindex, nofollow' }] });
</script>

<template>
  <NuxtPage />
</template>
