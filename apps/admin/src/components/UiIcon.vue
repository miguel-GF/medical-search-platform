<script setup lang="ts">
withDefaults(defineProps<{
  name: string;
  size?: number;
}>(), { size: 20 });
</script>

<template>
  <svg
    class="ui-icon"
    :width="size"
    :height="size"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="1.8"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <template v-if="name === 'overview'">
      <rect x="3" y="3" width="7" height="7" rx="2" />
      <rect x="14" y="3" width="7" height="7" rx="2" />
      <rect x="3" y="14" width="7" height="7" rx="2" />
      <rect x="14" y="14" width="7" height="7" rx="2" />
    </template>
    <template v-else-if="name === 'providers'">
      <path d="M3 21h18M5 21V7l7-4 7 4v14" />
      <path d="M9 9h1m4 0h1m-6 4h1m4 0h1m-6 4h6" />
    </template>
    <template v-else-if="name === 'locations'">
      <path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z" />
      <circle cx="12" cy="10" r="2.5" />
    </template>
    <template v-else-if="name === 'brand'">
      <path fill="currentColor" fill-rule="evenodd" stroke="none" transform="scale(.09375)" d="M32 46Q32 32 47 34C87 38 116 49 128 68V218C105 193 78 183 47 181Q32 180 32 166ZM56 176V75C78 77 99 80 109 87C121 95 126 107 124 120C122 133 114 141 103 144C93 146 83 143 74 140V181C68 179 62 178 56 176ZM74 94V121C84 123 93 127 99 125C104 123 107 119 107 113C107 106 104 101 98 99C92 96 84 95 74 94ZM136 68C150 49 181 36 218 24Q232 20 232 36V157Q232 167 221 168C182 172 155 188 136 218ZM156 87L207 68Q214 66 217 73Q220 80 212 83L161 102Q154 104 151 97Q148 90 156 87ZM156 119L194 105Q201 103 204 110Q207 117 199 120L161 134Q154 136 151 129Q148 122 156 119Z" />
    </template>
    <template v-else-if="name === 'offers'">
      <path d="M20 12v7a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-7" />
      <path d="M2 7h20v5H2zM12 21V7M7 7c-1.7 0-3-1-3-2.2S5.3 3 7 3c2.5 0 5 4 5 4s2.5-4 5-4c1.7 0 3 .6 3 1.8S18.7 7 17 7" />
    </template>
    <template v-else-if="name === 'prices'">
      <circle cx="12" cy="12" r="9" />
      <path d="M16 8.5c-.8-.7-2-1.1-3.3-1.1-1.8 0-3.2.9-3.2 2.2 0 3.3 6.8 1.5 6.8 4.8 0 1.3-1.4 2.2-3.4 2.2-1.5 0-2.9-.5-3.8-1.3M12.7 5.7v12.6" />
    </template>
    <template v-else-if="name === 'review'">
      <path d="M9 11l2 2 4-4" />
      <path d="M9 4h6m-7 0H6a2 2 0 0 0-2 2v14h16V6a2 2 0 0 0-2-2h-2" />
      <rect x="8" y="2" width="8" height="4" rx="2" />
    </template>
    <template v-else-if="name === 'records'">
      <ellipse cx="12" cy="5" rx="8" ry="3" />
      <path d="M4 5v6c0 1.7 3.6 3 8 3s8-1.3 8-3V5M4 11v6c0 1.7 3.6 3 8 3s8-1.3 8-3v-6" />
    </template>
    <template v-else-if="name === 'quality'">
      <path d="M12 22s8-3.5 8-10V5l-8-3-8 3v7c0 6.5 8 10 8 10Z" />
      <path d="m9 12 2 2 4-5" />
    </template>
    <template v-else-if="name === 'alerts'">
      <path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4" />
    </template>
    <template v-else-if="name === 'refresh'">
      <path d="M20 6v5h-5M4 18v-5h5" />
      <path d="M6.1 9a7 7 0 0 1 11.5-2.6L20 11M4 13l2.4 4.6A7 7 0 0 0 17.9 15" />
    </template>
    <template v-else-if="name === 'logout'">
      <path d="M10 17l5-5-5-5M15 12H3M21 19V5a2 2 0 0 0-2-2h-6" />
    </template>
    <template v-else-if="name === 'lock'">
      <rect x="4" y="10" width="16" height="11" rx="3" />
      <path d="M8 10V7a4 4 0 0 1 8 0v3M12 14v3" />
    </template>
    <template v-else-if="name === 'mail'">
      <rect x="3" y="5" width="18" height="14" rx="2" />
      <path d="m3 7 9 6 9-6" />
    </template>
    <template v-else-if="name === 'search'">
      <circle cx="10.8" cy="10.8" r="6.5" />
      <path d="m16 16 4.5 4.5" />
    </template>
    <template v-else-if="name === 'phone'">
      <rect x="7" y="2" width="10" height="20" rx="2" />
      <path d="M11 18h2" />
    </template>
    <template v-else-if="name === 'check'">
      <circle cx="12" cy="12" r="9" />
      <path d="m8 12 2.5 2.5L16 9" />
    </template>
    <template v-else-if="name === 'arrow'">
      <path d="M5 12h14m-5-5 5 5-5 5" />
    </template>
    <template v-else-if="name === 'menu'">
      <path d="M4 7h16M4 12h16M4 17h16" />
    </template>
    <template v-else-if="name === 'close'">
      <path d="m6 6 12 12M18 6 6 18" />
    </template>
    <template v-else>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 8v4m0 4h.01" />
    </template>
  </svg>
</template>
