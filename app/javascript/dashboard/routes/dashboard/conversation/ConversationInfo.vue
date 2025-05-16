<script setup>
import { computed } from 'vue';
import { getLanguageName } from 'dashboard/components/widgets/conversation/advancedFilterItems/languages';
import ContactDetailsItem from './ContactDetailsItem.vue';
import CustomAttributes from './customAttributes/CustomAttributes.vue';

const props = defineProps({
  conversationAttributes: {
    type: Object,
    default: () => ({}),
  },
  contactAttributes: {
    type: Object,
    default: () => ({}),
  },
});

const referer = computed(() => props.conversationAttributes.referer);
const initiatedAt = computed(
  () => props.conversationAttributes.initiated_at?.timestamp
);

const browserInfo = computed(() => props.conversationAttributes.browser);

const browserName = computed(() => {
  if (!browserInfo.value) return '';
  const { browser_name: name = '', browser_version: version = '' } =
    browserInfo.value;
  return `${name} ${version}`;
});

const browserLanguage = computed(() =>
  getLanguageName(props.conversationAttributes.browser_language)
);

const platformName = computed(() => {
  if (!browserInfo.value) return '';
  const { platform_name: name = '', platform_version: version = '' } =
    browserInfo.value;
  return `${name} ${version}`;
});

const createdAtIp = computed(() => props.contactAttributes.created_at_ip);

const orderId = computed(() => {
  const orderDetails = props.conversationAttributes.order_details;
  return orderDetails?.id ? `#${orderDetails.id}` : null;
});

function formatDateTime(dateTime) {
  if (!dateTime) return null;
  const date = new Date(dateTime);
  const options = { day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' };
  return date.toLocaleDateString('es-ES', options).replace('de ', '').replace(', ', ' ');
}

const orderDate = computed(() => {
  const orderDetails = props.conversationAttributes.order_details;
  return orderDetails?.date_created
    ? formatDateTime(orderDetails.date_created)
    : null;
});

const orderStatus = computed(() => {
  const orderDetails = props.conversationAttributes.order_details;
  if (!orderDetails?.status) return null;

  const statusMap = {
    pending: 'Pendiente',
    completed: 'Completada',
    cancelled: 'Cancelada',
    paid: 'Pagado'
  };

  return statusMap[orderDetails.status] || `${orderDetails.status}`;
});

const orderItems = props.conversationAttributes?.order_details?.order_items || [];

console.log('Order Items:', orderItems);

const staticElements = computed(() => {
  if (props.conversationAttributes.type_of_conversation === 'questions') {
    const itemPermalink = props.conversationAttributes.item_permalink || '';
    const itemTitle = props.conversationAttributes.item_title || 'Item desconocido';

    return [
      {
        content: itemPermalink,
        title: `Preguntas sobre la publicación:`,
        type: 'link',
      },
    ];
  }

  const baseElements = [
    {
      content: initiatedAt,
      title: 'CONTACT_PANEL.INITIATED_AT',
      key: 'static-initiated-at',
      type: 'static_attribute',
    },
    {
      content: browserLanguage,
      title: 'CONTACT_PANEL.BROWSER_LANGUAGE',
      key: 'static-browser-language',
      type: 'static_attribute',
    },
    {
      content: referer,
      title: 'CONTACT_PANEL.INITIATED_FROM',
      key: 'static-referer',
      type: 'static_attribute',
    },
    {
      content: browserName,
      title: 'CONTACT_PANEL.BROWSER',
      key: 'static-browser',
      type: 'static_attribute',
    },
    {
      content: platformName,
      title: 'CONTACT_PANEL.OS',
      key: 'static-platform',
      type: 'static_attribute',
    },
    {
      content: createdAtIp,
      title: 'CONTACT_PANEL.IP_ADDRESS',
      key: 'static-ip-address',
      type: 'static_attribute',
    },
    {
      content: orderId,
      title: 'ORDER_PANEL.ORDER_ID',
    },
    {
      content: orderDate,
      title: 'ORDER_PANEL.ORDER_DATE',
    },
    {
      content: orderStatus,
      title: 'ORDER_PANEL.ORDER_STATUS',
    },
  ].filter(attribute => !!attribute.content?.value);

  const orderDetails = props.conversationAttributes?.order_details || {};
  const orderItems = orderDetails.order_items || [];

  const orderItemElements = orderItems.map(orderItem => ({
    title: orderItem.item?.title || 'Producto sin nombre',
    content: `$${orderItem.unit_price || 0} x ${orderItem.quantity || 0} unidad(es)`,
  }));

  return [...baseElements, ...orderItemElements];
});

</script>

<template>
  <div class="conversation--details">
    <ContactDetailsItem
      v-for="element in staticElements"
      :key="element.title"
      :title="$t(element.title)"
      :value="element.content.value || element.content"
      class="conversation--attribute"
    >
      <!-- Agregar enlace solo para el caso de item_permalink -->
      <template v-if="element.type === 'link'">
        <a
          :href="element.content"
          rel="noopener noreferrer nofollow"
          target="_blank"
          class="text-woot-400 dark:text-woot-600"
        >
          {{ element.content }}
        </a>
      </template>

      <!-- Renderizar el contenido original cuando no sea un enlace -->
      <template v-else>
        {{ element.content }}
      </template>
    </ContactDetailsItem>

    <CustomAttributes
      :class="staticElements.length % 2 === 0 ? 'even' : 'odd'"
      attribute-class="conversation--attribute"
      attribute-from="conversation_panel"
      attribute-type="conversation_attribute"
    >
      <template #staticItem="{ element }">
        <ContactDetailsItem
          :key="element.title"
          :title="$t(element.title)"
          :value="element.content.value"
        >
          <a
            v-if="element.key === 'static-referer'"
            :href="element.content.value"
            rel="noopener noreferrer nofollow"
            target="_blank"
            class="text-n-brand"
          >
            {{ element.content.value }}
          </a>
        </ContactDetailsItem>
      </template>
    </CustomAttributes>
  </div>
</template>

<style scoped lang="scss">
.conversation--attribute {
  @apply border-slate-50 dark:border-slate-700/50 border-b border-solid;
}

.order-details--title {
  font-weight: bold;
}

.order-details p,
.order-details ul {
  margin-top: 10px;
}

.order-details ul {
  list-style-type: none;
  padding-left: 0;
}

.order-details li {
  margin-bottom: 8px;
}
</style>
