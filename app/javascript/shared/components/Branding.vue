<script>
import globalConfigMixin from 'shared/mixins/globalConfigMixin';

const { LOGO_THUMBNAIL: logoThumbnail, BRAND_NAME: brandName } =
  window.globalConfig || {};

export default {
  mixins: [globalConfigMixin],
  props: {
    disableBranding: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      globalConfig: {
        brandName,
        logoThumbnail,
      },
    };
  },
};
</script>

<template>
  <div
    v-if="globalConfig.brandName && !disableBranding"
    class="px-0 py-3 flex justify-center"
  >
    <a
      href="https://nuuxia.com"
      rel="noreferrer noopener nofollow"
      target="_blank"
      class="branding--link text-n-slate-11 hover:text-n-slate-12 cursor-pointer text-xs inline-flex grayscale-[1] hover:grayscale-0 hover:opacity-100 opacity-90 no-underline justify-center items-center leading-3"
    >
      <img
        class="ltr:mr-1 rtl:ml-1 max-w-3 max-h-3"
        :alt="globalConfig.brandName"
        :src="globalConfig.logoThumbnail"
      />
    </a>
  </div>
  <div v-else class="p-3" />
</template>
