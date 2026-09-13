<script setup lang="ts">
import UiIcon from './UiIcon.vue';

export interface FilterOption {
  label: string;
  value: string;
}

const DEFAULT_TIME_OPTIONS: FilterOption[] = [
  { label: 'Todo', value: 'all' },
  { label: '7 días', value: '7' },
  { label: '15 días', value: '15' },
  { label: '30 días', value: '30' },
];

const props = withDefaults(defineProps<{
  query: string;
  time?: string;
  status?: string;
  secondary?: string;
  placeholder?: string;
  showTime?: boolean;
  timeOptions?: FilterOption[];
  statusLabel?: string;
  statusOptions?: FilterOption[];
  secondaryLabel?: string;
  secondaryOptions?: FilterOption[];
}>(), {
  time: 'all',
  status: 'all',
  secondary: 'all',
  placeholder: 'Buscar por nombre, fuente o texto…',
  showTime: true,
  timeOptions: undefined,
  statusLabel: 'Estado',
  statusOptions: undefined,
  secondaryLabel: 'Tipo',
  secondaryOptions: undefined,
});

const emit = defineEmits<{
  (event: 'update:query', value: string): void;
  (event: 'update:time', value: string): void;
  (event: 'update:status', value: string): void;
  (event: 'update:secondary', value: string): void;
}>();

const timeOptions = () => props.timeOptions?.length ? props.timeOptions : DEFAULT_TIME_OPTIONS;
</script>

<template>
  <section class="table-filters" aria-label="Filtros de tabla">
    <label class="table-search">
      <UiIcon name="search" :size="17" />
      <span class="sr-only">Buscar</span>
      <input
        type="search"
        :value="query"
        :placeholder="placeholder"
        @input="emit('update:query', ($event.target as HTMLInputElement).value)"
      />
    </label>

    <div v-if="showTime" class="filter-group">
      <span class="filter-caption">Periodo</span>
      <div class="filter-pills" role="group" aria-label="Periodo">
        <button
          v-for="option in timeOptions()"
          :key="`time-${option.value}`"
          type="button"
          class="filter-pill"
          :class="{ active: time === option.value }"
          :aria-pressed="time === option.value"
          @click="emit('update:time', option.value)"
        >{{ option.label }}</button>
      </div>
    </div>

    <div v-if="statusOptions?.length" class="filter-group">
      <span class="filter-caption">{{ statusLabel }}</span>
      <div class="filter-pills" role="group" :aria-label="statusLabel">
        <button
          v-for="option in statusOptions"
          :key="`status-${option.value}`"
          type="button"
          class="filter-pill"
          :class="{ active: status === option.value }"
          :aria-pressed="status === option.value"
          @click="emit('update:status', option.value)"
        >{{ option.label }}</button>
      </div>
    </div>

    <div v-if="secondaryOptions?.length" class="filter-group">
      <span class="filter-caption">{{ secondaryLabel }}</span>
      <div class="filter-pills" role="group" :aria-label="secondaryLabel">
        <button
          v-for="option in secondaryOptions"
          :key="`secondary-${option.value}`"
          type="button"
          class="filter-pill"
          :class="{ active: secondary === option.value }"
          :aria-pressed="secondary === option.value"
          @click="emit('update:secondary', option.value)"
        >{{ option.label }}</button>
      </div>
    </div>
  </section>
</template>
