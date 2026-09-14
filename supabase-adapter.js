// Frontend adapter for AiSMUS.
// Load @supabase/supabase-js v2 before this file.
// Replace the placeholders with the project's publishable key and URL.
// Never put a service_role/secret key in this file.

const SUPABASE_URL = window.ASM_SUPABASE_URL || "";
const SUPABASE_PUBLISHABLE_KEY = window.ASM_SUPABASE_PUBLISHABLE_KEY || "";

if (!SUPABASE_URL || !SUPABASE_PUBLISHABLE_KEY) {
  console.warn("Supabase is not configured yet. The site will remain in demo/local mode.");
}

const asmSupabase = (window.supabase && SUPABASE_URL && SUPABASE_PUBLISHABLE_KEY)
  ? window.supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
    })
  : null;

async function asmUser() {
  if (!asmSupabase) return null;
  const { data } = await asmSupabase.auth.getUser();
  return data?.user || null;
}

async function asmRequireUser() {
  const user = await asmUser();
  if (!user) throw new Error("Please sign in first.");
  return user;
}

async function asmSignUp(email, password, displayName, accountType) {
  if (!asmSupabase) throw new Error("Backend is not configured.");
  const { data, error } = await asmSupabase.auth.signUp({
    email, password,
    options: { data: { display_name: displayName, account_type: accountType } }
  });
  if (error) throw error;
  if (data.user) {
    await asmSupabase.from("profiles").upsert({
      id: data.user.id, display_name: displayName, email,
      account_type: accountType || "customer"
    });
  }
  return data;
}

async function asmSignIn(email, password) {
  if (!asmSupabase) throw new Error("Backend is not configured.");
  const { data, error } = await asmSupabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

async function asmSignOut() {
  if (!asmSupabase) return;
  const { error } = await asmSupabase.auth.signOut();
  if (error) throw error;
}

async function asmSaveProfile(patch) {
  const user = await asmRequireUser();
  const { data, error } = await asmSupabase.from("profiles")
    .upsert({ id: user.id, email: user.email, ...patch }, { onConflict: "id" })
    .select().single();
  if (error) throw error;
  return data;
}

async function asmCreateRegistration(payload) {
  const user = await asmRequireUser();
  const { data, error } = await asmSupabase.from("registration_requests")
    .insert({
      user_id: user.id,
      full_name: payload.name,
      email: user.email || payload.email,
      account_type: payload.accountType || "customer",
      terms_accepted_at: new Date().toISOString()
    }).select().single();
  if (error) throw error;
  return data;
}

async function asmCreateOrder({ deliveryAddress, notes, referralUsername }) {
  await asmRequireUser();
  const { data, error } = await asmSupabase.rpc("create_order_from_cart", {
    p_delivery_address: deliveryAddress || null,
    p_notes: notes || null,
    p_referral_username: referralUsername || null
  });
  if (error) throw error;
  return data;
}

async function asmListPublishedProducts() {
  if (!asmSupabase) return [];
  const { data, error } = await asmSupabase.from("products")
    .select("*,product_media(*)")
    .eq("status","published")
    .order("created_at",{ascending:false});
  if (error) throw error;
  return data || [];
}

async function asmListPublishedServices() {
  if (!asmSupabase) return [];
  const { data, error } = await asmSupabase.from("services")
    .select("*").eq("status","published").order("created_at",{ascending:false});
  if (error) throw error;
  return data || [];
}

async function asmListPublishedPosts() {
  if (!asmSupabase) return [];
  const { data, error } = await asmSupabase.from("posts")
    .select("*").eq("status","published").order("created_at",{ascending:false});
  if (error) throw error;
  return data || [];
}

async function asmListPublishedRentals() {
  if (!asmSupabase) return [];
  const { data, error } = await asmSupabase.from("rentals")
    .select("*,rental_media(*)").eq("status","published").order("created_at",{ascending:false});
  if (error) throw error;
  return data || [];
}

async function asmActivity(type, icon, title, detail, metadata={}) {
  const user = await asmUser();
  if (!user || !asmSupabase) return;
  await asmSupabase.from("activity").insert({
    user_id:user.id, type, icon, title, detail, metadata
  });
}

async function asmUpload(bucket, file, folder) {
  const user = await asmRequireUser();
  const ext = (file.name.split(".").pop() || "bin").toLowerCase();
  const path = `${user.id}/${folder || crypto.randomUUID()}.${ext}`;
  const { error } = await asmSupabase.storage.from(bucket).upload(path, file, {
    upsert: false, contentType: file.type || undefined
  });
  if (error) throw error;
  if (bucket === "partner-docs") {
    const { data, error: signedError } = await asmSupabase.storage.from(bucket).createSignedUrl(path, 3600);
    if (signedError) throw signedError;
    return { path, publicUrl: data.signedUrl };
  }
  const { data } = asmSupabase.storage.from(bucket).getPublicUrl(path);
  return { path, publicUrl: data.publicUrl };
}

window.ASM = {
  client: asmSupabase,
  user: asmUser,
  signUp: asmSignUp,
  signIn: asmSignIn,
  signOut: asmSignOut,
  saveProfile: asmSaveProfile,
  createRegistration: asmCreateRegistration,
  createOrder: asmCreateOrder,
  products: asmListPublishedProducts,
  services: asmListPublishedServices,
  posts: asmListPublishedPosts,
  rentals: asmListPublishedRentals,
  activity: asmActivity,
  upload: asmUpload
};
